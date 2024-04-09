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
  let(:request_pipeline) { Core::ConnectorSettings::DEFAULT_REQUEST_PIPELINE }
  let(:es_client) { double }
  let(:bulk_queue) { double }
  let(:serializer) { double }

  let(:document) { { :id => 15 } }
  let(:serialized_document) { "id: #{document[:id]}, text: 'hoho, haha!'" }
  let(:deleted_id) { 25 }

  before(:each) do
    allow(Utility::EsClient).to receive(:new).and_return(es_client)
    allow(Utility::BulkQueue).to receive(:new).and_return(bulk_queue)

    allow(es_client).to receive(:bulk)

    allow(bulk_queue).to receive(:will_fit?).and_return(true)
    allow(bulk_queue).to receive(:add)
    allow(bulk_queue).to receive(:pop_all)
    allow(bulk_queue).to receive(:current_stats)

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
      end
    end
  end

  describe '#write' do
    let(:crawl_result) { FactoryBot.build(:html_crawl_result) }

    context 'when bulk queue still has capacity' do
      it 'does not immediately send the document into elasticsearch' do
        expect(es_client).to_not receive(:bulk)

        subject.write(crawl_result)
      end
    end

    context 'when bulk queue reports that it is full' do
      let(:crawl_result_one) { FactoryBot.build(:html_crawl_result, url: 'http://example.com/one', content: 'hoho, haha!') }
      let(:crawl_result_two) { FactoryBot.build(:html_crawl_result, url: 'http://example.com/two', content: 'work work!') }
      let(:serialized_document_one) { "doc: { id: #{crawl_result_one.url_hash}, body_content: hoho, haha! }" }
      let(:serialized_document_two) { "doc: { id: #{crawl_result_one.url_hash}, body_content: work work! }" }

      before(:each) do
        # emulated behaviour is:
        # Queue will be full once first item is added to it
        allow(bulk_queue).to receive(:will_fit?).and_return(true, false)
        allow(bulk_queue).to receive(:pop_all).and_return([serialized_document_one])

        allow(serializer).to receive(:dump).and_return(serialized_document_one, serialized_document_two)
      end

      it 'sends a bulk request with data returned from bulk queue' do
        expect(es_client).to receive(:bulk).once

        subject.write(crawl_result_one)
        subject.write(crawl_result_two)
      end

      it 'pops existing documents before adding a new one' do
        expect(bulk_queue).to receive(:add).with(anything, serialized_document_one).ordered
        expect(bulk_queue).to receive(:pop_all).ordered
        expect(bulk_queue).to receive(:add).with(anything, serialized_document_two).ordered

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
      expect(es_client).to receive(:bulk).with(hash_including(:body => operation))

      subject.flush
    end
  end

  describe '#ingestion_stats' do
    context 'when flush was not triggered' do
      let(:crawl_result) { FactoryBot.build(:html_crawl_result) }
      before(:each) do
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
          allow(serializer).to receive(:dump).and_return(serialized_object)

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
