# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink) do
  let(:domains) { ['http://example.com'] }
  let(:seed_urls) { ['http://example.com/'] }

  context '.create' do
    it 'should validate the sync name' do
      config = Crawler::API::Config.new(
        :domain_allowlist => domains,
        :seed_urls => seed_urls,
        :output_sink => 'magnetic-tape'
      )

      expect do
        Crawler::OutputSink.create(config)
      end.to raise_error(/Unknown output sink/)
    end

    it 'should return a new sink object of a correct type' do
      config = Crawler::API::Config.new(
        :domain_allowlist => domains,
        :seed_urls => seed_urls,
        :output_sink => 'console'
      )

      sink = Crawler::OutputSink.create(config)
      expect(sink).to be_kind_of(Crawler::OutputSink::Console)
    end
  end
end
