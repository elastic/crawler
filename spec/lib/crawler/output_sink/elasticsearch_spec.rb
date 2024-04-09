# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink::Elasticsearch) do
  let(:domains) { ['http://example.com'] }
  let(:seed_urls) { ['http://example.com/'] }
  let(:index_name) { 'my-index' }

  context '#initialize' do
    def new_sink(config)
      Crawler::OutputSink::Elasticsearch.new(config)
    end

    it 'should require an output index' do
      config = Crawler::API::Config.new(
        domain_allowlist: domains,
        seed_urls: seed_urls,
        output_sink: 'elasticsearch'
      )

      expect { new_sink(config) }.to raise_error(/Missing output index/)
    end

    it 'should require an elasticsearch config' do
      config = Crawler::API::Config.new(
        domain_allowlist: domains,
        seed_urls: seed_urls,
        output_sink: 'elasticsearch',
        output_index: index_name
      )

      expect { new_sink(config) }.to raise_error(/Missing elasticsearch configuration/)
    end

    it 'should initialise if index and elasticsearch config is included' do
      config = Crawler::API::Config.new(
        domain_allowlist: domains,
        seed_urls: seed_urls,
        output_sink: 'elasticsearch',
        output_index: index_name,
        elasticsearch: {
          host: 'http://veryreal.com',
          api_key: 'key'
        }
      )
      new_sink(config)
    end
  end
end
