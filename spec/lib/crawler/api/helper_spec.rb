#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::CLI::Helpers) do
  # let(:es_config) { 'spec/fixtures/elasticsearch.yml' }
  # let(:crawl_config) { 'spec/fixtures/crawl.yml' }

  let(:url) { 'https://localhost:80' }

  let(:crawl_config) do
    Crawler::API::Config.new(
      domains: [
        {
          url:,
          seed_urls: %w[https://localhost:80 https://localhost:80/news/]
        }
      ],
      schedule: {
        pattern: '* * * * *'
      },
      output_sink: :elasticsearch,
      output_index: 'test-index',
      max_crawl_depth: 2,
      max_title_size: 500,
      max_body_size: 5_242_880, # 5 megabytes
      max_keywords_size: 512,
      max_description_size: 512,
      max_indexed_links_count: 5,
      max_headings_count: 5,
      elasticsearch: {
        host: 'http://localhost',
        port: 9200,
        username: 'elastic',
        password: 'changeme',
        bulk_api: {
          max_items: 10,
          max_size_bytes: 1_048_576
        }
      }
    )
  end

  context 'when given a crawl config and elastic config' do
    it 'generates a new Config instance' do
      allow(Crawler::API::Config).to receive(:new).and_return(crawl_config)

      expect(
        Crawler::CLI::Helpers.load_crawl_config(
          'spec/fixtures/crawl.yml',
          'spec/fixtures/elasticsearch.yml'
        )
      ).to eq(Crawler::API::Config.new)
    end
  end
end
