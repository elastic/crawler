# frozen_string_literal: true

RSpec.describe(Crawler::Data::UrlQueue) do
  let(:domains) { ['http://example.com'] }
  let(:seed_urls) { ['http://example.com/'] }

  let(:config) do
    Crawler::API::Config.new(
      :domain_allowlist => domains,
      :seed_urls => seed_urls
    )
  end

  describe '.create' do
    it 'should return a queue object' do
      queue = Crawler::Data::UrlQueue.create(config)
      expect(queue).to be_kind_of(Crawler::Data::UrlQueue::Base)
    end
  end
end
