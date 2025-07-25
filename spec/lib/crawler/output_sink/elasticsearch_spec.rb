#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink::Elasticsearch) do
  let(:subject) { described_class.new(config) }
  let(:config) do
    Crawler::API::Config.new(
      domains:,
      output_sink: 'elasticsearch',
      output_index: index_name,
      elasticsearch: {
        host: 'http://localhost',
        port: 1234,
        api_key: 'key'
      }
    )
  end

  let(:domains) { [{ url: 'http://example.com' }] }
  let(:index_name) { 'my-index' }

  let(:index_name) { 'some-index-name' }
  let(:default_pipeline_v1) { Crawler::OutputSink::Elasticsearch::DEFAULT_PIPELINE_V1 }
  let(:default_pipeline_v2) { Crawler::OutputSink::Elasticsearch::DEFAULT_PIPELINE_V2 }
  let(:default_pipeline_params) { Crawler::OutputSink::Elasticsearch::DEFAULT_PIPELINE_PARAMS }
  let(:system_logger) { double }
  let(:es_client) { double }
  let(:es_client_indices) { double(:es_client_indices, refresh: double, exists: double) }
  let(:bulk_queue) { double }
  let(:serializer) { double }

  let(:document) { { id: 15 } }
  let(:serialized_document) { "id: #{document[:id]}, text: 'hoho, haha!'" }
  let(:deleted_id) { 25 }
  let(:version) { '8.99.0' }
  let(:build_flavor) { 'default' }
  let(:build_info) { { version: { number: version, build_flavor: } }.deep_stringify_keys }

  before(:each) do
    allow(ES::Client).to receive(:new).and_return(es_client)
    allow(ES::BulkQueue).to receive(:new).and_return(bulk_queue)
    allow(config).to receive(:system_logger).and_return(system_logger)

    allow(es_client).to receive(:bulk)
    allow(es_client).to receive(:info).and_return(build_info)
    allow(es_client).to receive(:indices).and_return(es_client_indices)
    allow(es_client).to receive(:paginated_search)

    allow(bulk_queue).to receive(:will_fit?).and_return(true)
    allow(bulk_queue).to receive(:add)
    allow(bulk_queue).to receive(:pop_all)
    allow(bulk_queue).to receive(:current_stats)
    allow(bulk_queue).to receive(:serialize)

    allow(system_logger).to receive(:debug)
    allow(system_logger).to receive(:info)
    allow(system_logger).to receive(:warn)

    allow(Elasticsearch::API).to receive(:serializer).and_return(serializer)
    allow(serializer).to receive(:dump).and_return('')
    allow(serializer).to receive(:dump).with(document).and_return(serialized_document)
  end

  describe '#initialize' do
    context 'when output index is missing' do
      let(:config) do
        Crawler::API::Config.new(
          domains:,
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
          domains:,
          output_sink: 'elasticsearch',
          output_index: index_name
        )
      end

      it 'raises an ArgumentError' do
        expect { subject }.to raise_error(ArgumentError, /Missing elasticsearch configuration/)
      end
    end

    context 'when connection to Elasticsearch cannot be established' do
      let(:expected_host) { "#{config.elasticsearch[:host]}:#{config.elasticsearch[:port]}" }

      before(:each) do
        allow(es_client).to receive(:info).and_raise(Elastic::Transport::Transport::Error)
      end

      it 'should raise an ESConnectionError' do
        expect { subject }.to raise_error(Errors::ExitIfESConnectionError)
        expect(system_logger).to have_received(:info).with(
          "Failed to reach ES at #{expected_host}: Elastic::Transport::Transport::Error"
        )
      end
    end

    context 'when connection to 8.x default Elasticsearch has been verified' do
      let(:expected_log) do
        <<~LOG.squish
          Connected to ES at #{config.elasticsearch[:host]}:#{config.elasticsearch[:port]} -#{' '}
          version: 8.99.0; build flavor: default
        LOG
      end

      it 'should assign the v1 pipeline' do
        expect { subject }.not_to raise_error
        expect(system_logger).to have_received(:info).with(expected_log)
        expect(subject.instance_variable_get(:@default_pipeline)).to eq(default_pipeline_v1)
      end
    end

    context 'when connection to 8.x serverless Elasticsearch has been verified' do
      let(:build_flavor) { 'serverless' }
      let(:expected_log) do
        <<~LOG.squish
          Connected to ES at #{config.elasticsearch[:host]}:#{config.elasticsearch[:port]} -#{' '}
          version: 8.99.0; build flavor: serverless
        LOG
      end

      it 'should assign the v2 pipeline' do
        expect { subject }.not_to raise_error
        expect(system_logger).to have_received(:info).with(expected_log)
        expect(subject.instance_variable_get(:@default_pipeline)).to eq(default_pipeline_v2)
      end
    end

    context 'when connection to 9.x default Elasticsearch has been verified' do
      let(:version) { '9.99.0' }
      let(:expected_log) do
        <<~LOG.squish
          Connected to ES at #{config.elasticsearch[:host]}:#{config.elasticsearch[:port]} -#{' '}
          version: 9.99.0; build flavor: default
        LOG
      end

      it 'should assign the v2 pipeline' do
        expect { subject }.not_to raise_error
        expect(system_logger).to have_received(:info).with(expected_log)
        expect(subject.instance_variable_get(:@default_pipeline)).to eq(default_pipeline_v2)
      end
    end

    context 'when connection to 9.x serverless Elasticsearch has been verified' do
      let(:version) { '9.99.0' }
      let(:build_flavor) { 'serverless' }
      let(:expected_log) do
        <<~LOG.squish
          Connected to ES at #{config.elasticsearch[:host]}:#{config.elasticsearch[:port]} -#{' '}
          version: 9.99.0; build flavor: serverless
        LOG
      end

      it 'should assign the v2 pipeline' do
        expect { subject }.not_to raise_error
        expect(system_logger).to have_received(:info).with(expected_log)
        expect(subject.instance_variable_get(:@default_pipeline)).to eq(default_pipeline_v2)
      end
    end

    context 'when output index is provided but index does not exist in ES' do
      before(:each) do
        allow(es_client_indices).to receive(:exists).and_return(false)
        allow(es_client_indices).to receive(:create).and_return({ 'some' => 'response' })
        allow(subject).to receive(:verify_output_index)
      end

      it 'should create the index' do
        expect(system_logger).to have_received(:info).with(
          "Index [#{index_name}] did not exist, but was successfully created!"
        )
      end
    end

    context 'when output index is provided and index does not exist, but creation fails' do
      before(:each) do
        allow(es_client_indices).to receive(:exists).and_return(false)
        allow(es_client_indices).to receive(:create).and_return(false)
      end

      it 'raises ExitIfUnableToCreateIndex' do
        expect { subject.attempt_index_creation_or_exit }.to raise_error(Errors::ExitIfUnableToCreateIndex)
        expect(system_logger).to have_received(:info).with(
          "Failed to create #{index_name}"
        )
      end
    end

    context 'when output index is provided and index exists in ES' do
      before(:each) do
        allow(es_client).to receive(:exists).and_return({ 'some' => 'response' })
      end

      it 'does not raise an error' do
        expect { subject }.not_to raise_error
        expect(system_logger).to have_received(:info).with("Index [#{index_name}] was found!")
      end
    end

    context 'when config is okay' do
      it 'does not raise an error' do
        expect { subject }.not_to raise_error

        expect(subject.es_config).to eq(config.elasticsearch)
        expect(subject.index_name).to eq(index_name)
        expect(subject.pipeline_enabled?).to eq(true)
        expect(subject.pipeline).to eq(default_pipeline_v1)
        expect(subject.pipeline_params).to eq(default_pipeline_params)

        expect(system_logger).to have_received(:info).with(
          "Elasticsearch sink initialized for index [#{index_name}] with pipeline [#{default_pipeline_v1}]"
        )
      end
    end

    context 'when elasticsearch.pipeline is provided' do
      let(:config) do
        Crawler::API::Config.new(
          domains:,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost',
            port: 1234,
            api_key: 'key',
            pipeline: 'my-pipeline'
          }
        )
      end

      it 'uses the specified pipeline' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline).to eq('my-pipeline')
        expect(system_logger).to have_received(:info).with(
          "Elasticsearch sink initialized for index [#{index_name}] with pipeline [my-pipeline]"
        )
      end
    end

    context 'when elasticsearch.pipeline_enabled is false' do
      let(:config) do
        Crawler::API::Config.new(
          domains:,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost',
            port: 1234,
            api_key: 'key',
            pipeline_enabled: false
          }
        )
      end

      it 'does not use a pipeline' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline).to eq(nil)
        expect(system_logger).to have_received(:info).with(
          "Elasticsearch sink initialized for index [#{index_name}] with pipeline disabled"
        )
      end
    end

    context 'when elasticsearch.pipeline is not provided for version 8.x' do
      let(:config) do
        Crawler::API::Config.new(
          domains:,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost',
            port: 1234,
            api_key: 'key'
          }
        )
      end

      it 'uses the ent-search-generic-ingestion pipeline' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline).to eq('ent-search-generic-ingestion')
        expect(system_logger).to have_received(:info).with(
          "Elasticsearch sink initialized for index [#{index_name}] with pipeline [ent-search-generic-ingestion]"
        )
      end
    end

    context 'when elasticsearch.pipeline is not provided for version 9.x' do
      let(:version) { '9.99.0' }
      let(:config) do
        Crawler::API::Config.new(
          domains:,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost',
            port: 1234,
            api_key: 'key'
          }
        )
      end

      it 'uses the search-default-ingestion pipeline' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline).to eq('search-default-ingestion')
        expect(system_logger).to have_received(:info).with(
          "Elasticsearch sink initialized for index [#{index_name}] with pipeline [search-default-ingestion]"
        )
      end
    end

    context 'when elasticsearch.pipeline_params are changed' do
      let(:config) do
        Crawler::API::Config.new(
          domains:,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost',
            port: 1234,
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
        }
      end

      it 'overrides the specified default params and includes new ones' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline_params).to eq(expected_pipeline_params)
      end
    end

    context 'when elasticsearch.pipeline_enabled is false' do
      let(:config) do
        Crawler::API::Config.new(
          domains:,
          output_sink: 'elasticsearch',
          output_index: index_name,
          elasticsearch: {
            host: 'http://localhost',
            port: 1234,
            api_key: 'key',
            pipeline_enabled: false
          }
        )
      end

      it 'overrides the specified default params' do
        expect { subject }.not_to raise_error
        expect(subject.pipeline_enabled?).to eq(false)
        expect(subject.pipeline).to eq(nil)
      end
    end
  end

  describe '#write' do
    let(:crawl_result) { FactoryBot.build(:html_crawl_result, content: 'some page') }
    let(:index_op) { { index: { _index: index_name, _id: crawl_result.url_hash } } }

    before(:each) do
      # bytesize is only required for adding ingested doc size to stats, any value is fine for these tests
      allow(bulk_queue).to receive(:bytesize).and_return(50)
    end

    context 'when bulk queue still has capacity' do
      let(:expected_doc) do
        {
          id: crawl_result.url_hash,
          body: 'some page',
          _reduce_whitespace: true,
          _run_ml_inference: true,
          _extract_binary_content: true
        }
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
      let(:big_doc) { { id: big_crawl_result.url_hash, body: 'pretend this string is big' } }

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
      let(:doc_one) { { id: crawl_result_one.url_hash, body: 'hoho, haha!' } }
      let(:doc_two) { { id: crawl_result_two.url_hash, body: 'work work!' } }

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

      it 'blocks simultaneous threads with locking' do
        # this will call write 3 times
        # first call will take the lock and add crawl_result_one's doc
        # second call will be rejected due to locking
        # third call (retry of second call) will take the lock and add crawl_result_two's doc
        # we can test this by using `ordered` on the spies
        expect(bulk_queue).to receive(:add).with(anything, hash_including(doc_one)).ordered
        expect(bulk_queue).to receive(:pop_all).ordered
        expect(bulk_queue).to receive(:add).with(anything, hash_including(doc_two)).ordered

        # initially send multi-threaded to engage lock
        threads = [crawl_result_one, crawl_result_two].map do |crawl_result|
          Thread.new do
            subject.write(crawl_result)
          end
        end
        # second call will fail, but we can't differentiate that here
        expect { threads.each(&:join) }.to raise_error(Errors::SinkLockedError)

        # mock reattempting after failed lock acquisition
        subject.write(crawl_result_two)
      end
    end

    context 'when crawl result is of type ContentExtractableFile' do
      let(:file_name) { 'real.pdf' }
      let(:content_length) { 1234 }
      let(:crawl_result) do
        FactoryBot.build(
          :content_extractable_file_crawl_result,
          url: "http://example.com/#{file_name}",
          content_length:
        )
      end
      let(:expected_doc) do
        {
          id: crawl_result.url_hash,
          content_length:,
          file_name:,
          _attachment: crawl_result.base64_encoded_content,
          _reduce_whitespace: true,
          _run_ml_inference: true,
          _extract_binary_content: true
        }
      end

      it 'does not immediately send the document into elasticsearch' do
        # using an empty queue for this test, so bulk should never be called
        expect(es_client).to_not receive(:bulk)

        subject.write(crawl_result)
        expect(bulk_queue).to have_received(:add).with(index_op, hash_including(expected_doc))
      end
    end
  end

  describe '#fetch_purge_docs' do
    let(:crawl_start_time) { Time.now }
    let(:expected_query) do
      {
        _source: ['url'],
        query: {
          range: {
            last_crawled_at: {
              lt: crawl_start_time.rfc3339
            }
          }
        },
        size: Crawler::OutputSink::Elasticsearch::SEARCH_PAGINATION_SIZE,
        sort: [{ last_crawled_at: 'asc' }]
      }.deep_stringify_keys
    end
    let(:hit1) do
      {
        _id: '1234',
        _source: { url: 'https://www.elastic.co/search-labs' },
        sort: [1]
      }.deep_stringify_keys
    end
    let(:hit2) do
      {
        _id: '5678',
        _source: { url: 'https://www.elastic.co/search-labs/tutorials' },
        sort: [2]
      }.deep_stringify_keys
    end
    let(:es_results) do
      [hit1, hit2]
    end
    let(:formatted_results) do
      %w[https://www.elastic.co/search-labs https://www.elastic.co/search-labs/tutorials]
    end

    before do
      allow(es_client).to receive(:paginated_search).and_return(es_results)
    end

    it 'builds a query and requests a paginated search from the client' do
      expect(es_client_indices).to receive(:refresh).with(index: [index_name]).once
      expect(es_client).to receive(:paginated_search).with(index_name, expected_query).once

      results = subject.fetch_purge_docs(crawl_start_time)
      expect(results).to match_array(formatted_results)
    end
  end

  describe '#purge' do
    let(:crawl_start_time) { Time.now }
    let(:expected_query) do
      {
        _source: ['url'],
        query: {
          range: {
            last_crawled_at: {
              lt: crawl_start_time.rfc3339
            }
          }
        }
      }.deep_stringify_keys
    end

    before do
      allow(es_client).to receive(:delete_by_query).and_return({ deleted: 5 }.stringify_keys)
    end

    it 'builds a query and requests a delete by query from the client' do
      expect(es_client)
        .to receive(:delete_by_query).with(index: [index_name], body: expected_query).once

      result = subject.purge(crawl_start_time)
      expect(result).to eq(5)
    end
  end

  describe '#flush' do
    let(:operation) do
      [
        { index: { _index: 'my-index', _id: '1234' } },
        { id: '202d2df297ed4e62b51dff33ee1418330a93a622', title: 'foo' }
      ]
    end

    before(:each) do
      allow(bulk_queue).to receive(:pop_all).and_return(operation)
    end

    it 'sends data from bulk queue to elasticsearch' do
      expect(es_client).to receive(:bulk).with(hash_including(body: operation, pipeline: default_pipeline_v1))
      expect(system_logger).to receive(:info).with('Successfully indexed 1 docs.')

      subject.flush
    end

    context('when an error occurs during indexing') do
      before(:each) do
        allow(es_client).to receive(:bulk).and_raise(ES::Client::IndexingFailedError.new('BOOM'))
      end

      it 'logs error' do
        expect(es_client).to receive(:bulk).with(hash_including(body: operation, pipeline: default_pipeline_v1))
        expect(system_logger).to receive(:warn).with('Bulk index failed: BOOM')

        subject.flush
      end
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

        expect(stats[:completed][:docs_count]).to eq(0)
        expect(stats[:failed][:docs_volume]).to eq(0)
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

          expect(stats[:completed][:docs_count]).to eq(0)
          expect(stats[:failed][:docs_volume]).to eq(0)
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

        it 'returns expected docs_count' do
          stats = subject.ingestion_stats

          expect(stats[:completed][:docs_count]).to eq(document_count)
          expect(stats[:failed][:docs_count]).to eq(0)
        end

        it 'returns expected docs_volume' do
          stats = subject.ingestion_stats

          expect(stats[:completed][:docs_volume]).to eq(document_count * serialized_object.bytesize)
          expect(stats[:failed][:docs_volume]).to eq(0)
        end
      end

      context 'when some documents failed to be ingested' do
        let(:document_count) { 5 }
        let(:serialized_object) { 'doesnt matter' }

        before(:each) do
          allow(bulk_queue).to receive(:bytesize).and_return(serialized_object.bytesize)
          allow(es_client).to receive(:bulk).and_raise(ES::Client::IndexingFailedError.new('BOOM'))

          document_count.times.each do |x|
            subject.write(FactoryBot.build(:html_crawl_result, url: "http://real.com/#{x}"))
          end

          subject.flush
        end

        it 'returns expected docs_count' do
          stats = subject.ingestion_stats

          expect(stats[:failed][:docs_count]).to eq(document_count)
          expect(stats[:completed][:docs_count]).to eq(0)
          expect(system_logger).to have_received(:warn).with('Bulk index failed: BOOM')
        end

        it 'returns expected docs_volume' do
          stats = subject.ingestion_stats

          expect(stats[:failed][:docs_volume]).to eq(document_count * serialized_object.bytesize)
          expect(stats[:completed][:docs_volume]).to eq(0)
          expect(system_logger).to have_received(:warn).with('Bulk index failed: BOOM')
        end
      end
    end
  end
end
