#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::CLI::Helpers) do
  let(:crawl_configuration) do
    Crawler::API::Config.new(
      domains: [
        {
          url: 'https://localhost:80',
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
        },
        pipeline_params: {
          _reduce_whitespace: true,
          _run_ml_inference: true,
          _extract_binary_content: true
        }
      }
    )
  end

  crawl_config_fixture = 'spec/fixtures/crawl.yml'
  es_config_fixture = 'spec/fixtures/elasticsearch.yml'
  es_config_flat_fixture = 'spec/fixtures/elasticsearch-flat-format.yml'

  before do
    allow(Crawler::API::Config).to receive(:new).and_return(crawl_configuration)
  end

  context 'when given just a crawl config' do
    it 'generates a new Config instance' do
      expect(
        Crawler::CLI::Helpers.load_crawl_config(
          crawl_config_fixture,
          nil
        )
      ).to eq(crawl_configuration)
    end
  end

  context 'when given a crawl and elasticsearch config' do
    it 'generates a new Config instance with nested YAML' do
      expect(
        Crawler::CLI::Helpers.load_crawl_config(
          crawl_config_fixture,
          es_config_fixture
        )
      ).to eq(crawl_configuration)
    end

    it 'generates a new Config instance with flat YAML' do
      expect(
        Crawler::CLI::Helpers.load_crawl_config(
          crawl_config_fixture,
          es_config_flat_fixture
        )
      ).to eq(crawl_configuration)
    end
  end

  context 'crawler config takes precedence over elasticsearch config' do
    it 'we receive a config that contains settings from the crawl config' do
      # the es_config_flat_fixture contains different elasticsearch config values
      # therefore we check that the crawl config fixture's values were kept
      output_config = Crawler::CLI::Helpers.load_crawl_config(
        crawl_config_fixture,
        es_config_flat_fixture
      )
      expect(output_config.elasticsearch).to eq(crawl_configuration.elasticsearch)
    end
  end

  context 'when given flat YAML' do
    it 'is successfully nested' do
      output_config = Crawler::CLI::Helpers.load_crawl_config(
        crawl_config_fixture,
        es_config_flat_fixture
      )
      expect(
        output_config.elasticsearch[:pipeline_params]
      ).to eq(crawl_configuration.elasticsearch[:pipeline_params])
    end
  end
end
