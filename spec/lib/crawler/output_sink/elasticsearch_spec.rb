# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink::Elasticsearch) do
  let(:subject) { described_class.new(config) }
  let(:config) do
    Crawler::API::Config.new(
      domain_allowlist: domains,
      seed_urls: seed_urls,
      output_sink: 'elasticsearch',
      output_index: index_name,
      elasticsearch: {
        host: 'http://localhost:1234',
        api_key: 'key'
      }
    )
  end

  let(:domains) { ['http://example.com'] }
  let(:seed_urls) { ['http://example.com/'] }
  let(:index_name) { 'my-index' }

  let(:index_name) { 'some-index-name' }
  let(:default_pipeline) { Crawler::OutputSink::Elasticsearch::DEFAULT_PIPELINE }
  let(:default_pipeline_params) { Crawler::OutputSink::Elasticsearch::DEFAULT_PIPELINE_PARAMS.deep_stringify_keys }
  let(:system_logger) { double }
  let(:es_client) { double }
  let(:bulk_queue) { double }
  let(:serializer) { double }

  let(:document) { { id: 15 } }
  let(:serialized_document) { "id: #{document[:id]}, text: 'hoho, haha!'" }
  let(:deleted_id) { 25 }

  before(:each) do
    allow(Utility::EsClient).to receive(:new).and_return(es_client)
    allow(Utility::BulkQueue).to receive(:new).and_return(bulk_queue)
    allow(config).to receive(:system_logger).and_return(system_logger)

    allow(es_client).to receive(:bulk)

    allow(bulk_queue).to receive(:will_fit?).and_return(true)
    allow(bulk_queue).to receive(:add)
    allow(bulk_queue).to receive(:pop_all)
    allow(bulk_queue).to receive(:current_stats)
    allow(bulk_queue).to receive(:serialize)

    allow(system_logger).to receive(:debug)
    allow(system_logger).to receive(:info)

    allow(Elasticsearch::API).to receive(:serializer).and_return(serializer)
    allow(serializer).to receive(:dump).and_return('')
    allow(serializer).to receive(:dump).with(document).and_return(serialized_document)
  end

  describe '#initialize' do
    context 'when output index is missing' do
      let(:config) do
        Crawler::API::Config.new(
          domain_allowlist: domains,
          seed_urls: seed_urls,
          output_sink: 'elasticsearch'
        )
      end

      it 'raises an ArgumentError' do
        expect { subject }.to raise_error(ArgumentError, /Missing output index/)
      end
    end

    context 'when elasticsearch config is missing' do
      let(:config) do
        Crawler::API::Config.new(
          domain_allowlist: domains,
          seed_urls: seed_urls,
          output_sink: 'elasticsearch',
          output_index: index_name
        )
      end

      it 'raises an ArgumentError' do
        expect { subject }.to raise_error(ArgumentError, /Missing elasticsearch configuration/)
      end
    end

    context 'when config is okay' do
      it 'does not raise an error' do
        expect { subject }.not_to raise_error

        expect(subject.es_config).to eq(config.elasticsearch)
        expect(subject.index_name).to eq(index_name)
        expect(subject.pipeline_enabled?).to eq(true)
        expect(subject.pipeline).to eq(default_pipeline)
        expect(subject.pipeline_params).to eq(default_pipeline_params)

        expect(system_logger).to have_received(:info).with(
          "Elasticsearch sink initialized for index [#{index_name}] with pipeline [#{default_pipeline}]"
        )
      end
    end

    context 'when elasticsearch.pipeline is not provided' do
      let(:config) do
        Crawler::API::Config.new(
          domain_allowlist: domains,
          seed_urls: seed_urls,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost:1234',
            api_key: 'key',
            pipeline: 'my-pipeline'
          }
        )
      end

      it 'uses the default pipeline' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline).to eq('my-pipeline')
        expect(system_logger).to have_received(:info).with(
          "Elasticsearch sink initialized for index [#{index_name}] with pipeline [my-pipeline]"
        )
      end
    end

    context 'when elasticsearch.pipeline_params are changed' do
      let(:config) do
        Crawler::API::Config.new(
          domain_allowlist: domains,
          seed_urls: seed_urls,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost:1234',
            api_key: 'key',
            pipeline: 'my-pipeline',
            pipeline_params: {
              _reduce_whitespace: false,
              _foo_param: true
            }
          }
        )
      end
      let(:expected_pipeline_params) do
        # DEFAULT_PIPELINE_PARAMS with alterations
        {
          _reduce_whitespace: false,
          _run_ml_inference: true,
          _extract_binary_content: true,
          _foo_param: true
        }.stringify_keys
      end

      it 'overrides the specified default params and includes new ones' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline_params).to eq(expected_pipeline_params)
      end
    end

    context 'when elasticsearch.pipeline_enabled is false' do
      let(:config) do
        Crawler::API::Config.new(
          domain_allowlist: domains,
          seed_urls: seed_urls,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost:1234',
            api_key: 'key',
            pipeline_enabled: false
          }
        )
      end

      it 'overrides the specified default params and includes new ones' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline_enabled?).to eq(false)
      end
    end
  end

  describe '#write' do
    let(:crawl_result) { FactoryBot.build(:html_crawl_result, content: 'some page') }
    let(:index_op) { { 'index' => { '_index' => index_name, '_id' => crawl_result.url_hash } } }

    before(:each) do
      # bytesize is only required for adding ingested doc size to stats, any value is fine for these tests
      allow(bulk_queue).to receive(:bytesize).and_return(50)
    end

    context 'when bulk queue still has capacity' do
      let(:expected_doc) do
        {
          id: crawl_result.url_hash,
          body_content: 'some page',
          _reduce_whitespace: true,
          _run_ml_inference: true,
          _extract_binary_content: true
        }.stringify_keys
      end

      it 'does not immediately send the document into elasticsearch' do
        expect(es_client).to_not receive(:bulk)

        subject.write(crawl_result)
        expect(bulk_queue).to have_received(:add).with(index_op, hash_including(expected_doc))
      end
    end

    context 'when bulk queue is empty but first doc is too big for queue' do
      let(:big_crawl_result) do
        FactoryBot.build(:html_crawl_result, url: 'http://example.com/big', content: 'pretend this string is big')
      end
      let(:big_doc) { { id: big_crawl_result.url_hash, body_content: 'pretend this string is big' }.stringify_keys }

      before(:each) do
        allow(bulk_queue).to receive(:will_fit?).and_return(false)
        allow(bulk_queue).to receive(:pop_all).and_return([])
      end

      it 'does not immediately send the document into elasticsearch' do
        # emulated behaviour is:
        # Empty queue will be popped before adding large doc
        expect(bulk_queue).to receive(:pop_all).ordered
        expect(bulk_queue).to receive(:add).with(anything, hash_including(big_doc)).ordered

        subject.write(big_crawl_result)
      end
    end

    context 'when bulk queue reports that it is full' do
      let(:crawl_result_one) do
        FactoryBot.build(:html_crawl_result, url: 'http://example.com/one', content: 'hoho, haha!')
      end
      let(:crawl_result_two) do
        FactoryBot.build(:html_crawl_result, url: 'http://example.com/two', content: 'work work!')
      end
      let(:doc_one) { { id: crawl_result_one.url_hash, body_content: 'hoho, haha!' }.stringify_keys }
      let(:doc_two) { { id: crawl_result_two.url_hash, body_content: 'work work!' }.stringify_keys }

      before(:each) do
        # emulated behaviour is:
        # Queue will be full once first item is added to it
        allow(bulk_queue).to receive(:will_fit?).and_return(true, false)
        allow(bulk_queue).to receive(:pop_all).and_return([doc_one])
      end

      it 'sends a bulk request with data returned from bulk queue' do
        expect(es_client).to receive(:bulk).once

        subject.write(crawl_result_one)
        subject.write(crawl_result_two)
      end

      it 'pops existing documents before adding a new one' do
        expect(bulk_queue).to receive(:add).with(anything, hash_including(doc_one)).ordered
        expect(bulk_queue).to receive(:pop_all).ordered
        expect(bulk_queue).to receive(:add).with(anything, hash_including(doc_two)).ordered

        subject.write(crawl_result_one)
        subject.write(crawl_result_two)
      end
    end
  end

  describe '#flush' do
    let(:operation) { 'bulk: delete something \n insert something else' }

    before(:each) do
      allow(bulk_queue).to receive(:pop_all).and_return(operation)
    end

    it 'sends data from bulk queue to elasticsearch' do
      expect(es_client).to receive(:bulk).with(hash_including(body: operation, pipeline: default_pipeline))

      subject.flush
    end
  end

  describe '#ingestion_stats' do
    context 'when flush was not triggered' do
      let(:crawl_result) { FactoryBot.build(:html_crawl_result) }
      before(:each) do
        allow(bulk_queue).to receive(:bytesize).and_return(10) # arbitrary
        15.times.each do |x|
          subject.write(FactoryBot.build(:html_crawl_result, url: "http://real.com/#{x}"))
        end
      end

      it 'returns empty stats' do
        stats = subject.ingestion_stats

        expect(stats[:indexed_document_count]).to eq(0)
        expect(stats[:indexed_document_volume]).to eq(0)
      end
    end

    context 'when flush was triggered' do
      let(:operation) { 'bulk: delete something \n insert something else' }

      before(:each) do
        allow(bulk_queue).to receive(:pop_all).and_return(operation)
      end

      context 'when nothing was ingested yet' do
        it 'returns empty stats' do
          stats = subject.ingestion_stats

          expect(stats[:indexed_document_count]).to eq(0)
          expect(stats[:indexed_document_volume]).to eq(0)
        end
      end

      context 'when some documents were ingested' do
        let(:document_count) { 5 }
        let(:serialized_object) { 'doesnt matter' }

        before(:each) do
          allow(bulk_queue).to receive(:bytesize).and_return(serialized_object.bytesize)

          document_count.times.each do |x|
            subject.write(FactoryBot.build(:html_crawl_result, url: "http://real.com/#{x}"))
          end

          subject.flush
        end

        it 'returns expected indexed_document_count' do
          stats = subject.ingestion_stats

          expect(stats[:indexed_document_count]).to eq(document_count)
        end

        it 'returns expected indexed_document_volume' do
          stats = subject.ingestion_stats

          expect(stats[:indexed_document_volume]).to eq(document_count * serialized_object.bytesize)
        end
      end
    end
  end
end
