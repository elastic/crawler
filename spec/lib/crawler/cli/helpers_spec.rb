# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'yaml'
require 'crawler/cli/helpers'
require 'crawler/api/config'

RSpec.describe Crawler::CLI::Helpers do
  describe '.load_yaml' do
    let(:tmpfile) { Tempfile.new('config.yml') }

    after { tmpfile.close! }

    it 'loads YAML content from a file path' do
      yaml_content = { 'key' => 'value', 'nested' => { 'subkey' => 123 } }
      tmpfile.write(YAML.dump(yaml_content))
      tmpfile.rewind
      expect(described_class.load_yaml(tmpfile.path)).to eq(yaml_content)
    end

    it 'returns nil if the file is empty' do
      tmpfile.write('')
      tmpfile.rewind
      expect(described_class.load_yaml(tmpfile.path)).to be_nil
    end

    it 'exits if the file does not exist' do
      non_existent_path = '/path/to/non/existent/file.yml'
      expect { described_class.load_yaml(non_existent_path) }.to raise_error(SystemExit)
    end

    it 'exits for invalid YAML syntax' do
      tmpfile.write('key: [unclosed')
      tmpfile.rewind
      allow(described_class).to receive(:puts) # Prevent noise during test
      expect { described_class.load_yaml(tmpfile.path) }.to raise_error(SystemExit)
    end
  end

  describe '.load_crawl_config' do
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

    let(:crawl_config_fixture) { 'spec/fixtures/crawl.yml' }
    let(:es_config_fixture) { 'spec/fixtures/elasticsearch.yml' }
    let(:crawl_config_flat_fixture) { 'spec/fixtures/crawl-flat-format.yml' }
    let(:es_config_flat_fixture) { 'spec/fixtures/elasticsearch-flat-format.yml' }
    let(:es_config_partially_flat_fixture) { 'spec/fixtures/elasticsearch-partially-flat-format.yml' }

    before do
      allow(Crawler::API::Config).to receive(:new).and_return(crawl_configuration)
    end

    context 'when given just a crawl config' do
      it 'generates a new Config instance' do
        expect(
          described_class.load_crawl_config(
            crawl_config_fixture,
            nil
          )
        ).to eq(crawl_configuration)
      end
    end

    context 'when given a crawl and elasticsearch config' do
      it 'generates a new Config instance with nested YAML' do
        expect(
          described_class.load_crawl_config(
            crawl_config_fixture,
            es_config_fixture
          )
        ).to eq(crawl_configuration)
      end

      it 'generates a new Config instance with flat YAML' do
        expect(
          described_class.load_crawl_config(
            crawl_config_fixture,
            es_config_flat_fixture
          )
        ).to eq(crawl_configuration)
      end

      it 'generates a new Config instance with YAML of mixed-flatness' do
        expect(
          described_class.load_crawl_config(
            crawl_config_fixture,
            es_config_partially_flat_fixture
          )
        ).to eq(crawl_configuration)
      end
    end

    context 'when crawler and elasticsearch have conflicting fields' do
      it 'prioritizes the crawler YAML file over elasticsearch' do
        output_config = described_class.load_crawl_config(
          crawl_config_fixture,
          es_config_flat_fixture
        )
        expect(output_config.elasticsearch).to eq(crawl_configuration.elasticsearch)
      end
    end

    context 'when given flat YAML' do
      it 'is successfully nested', :aggregate_failures do
        output_config = described_class.load_crawl_config(
          crawl_config_flat_fixture,
          es_config_flat_fixture
        )

        expect(
          output_config.domains
        ).to eq(crawl_configuration.domains)

        expect(
          output_config.elasticsearch
        ).to eq(crawl_configuration.elasticsearch)

        expect(
          output_config.elasticsearch[:pipeline_params]
        ).to eq(crawl_configuration.elasticsearch[:pipeline_params])
      end
    end
  end

  describe '.nest_configs' do
    it 'returns an empty hash for nil/empty input' do
      expect(described_class.nest_configs(nil)).to eq({})
      expect(described_class.nest_configs({})).to eq({})
    end

    it 'unnests simple dot notation keys' do
      input = { 'a.b' => 1, 'c.d' => 2 }
      expected = { 'a' => { 'b' => 1 }, 'c' => { 'd' => 2 } }
      expect(described_class.nest_configs(input)).to eq(expected)
    end

    it 'unnests multiple levels of dot notation' do
      input = { 'a.b.c' => 1, 'x.y.z' => 'hello' }
      expected = { 'a' => { 'b' => { 'c' => 1 } }, 'x' => { 'y' => { 'z' => 'hello' } } }
      expect(described_class.nest_configs(input)).to eq(expected)
    end

    it 'handles mixed dot notation and regular keys' do
      input = { 'a.b' => 1, 'c' => 2, 'd.e.f' => 3 }
      expected = { 'a' => { 'b' => 1 }, 'c' => 2, 'd' => { 'e' => { 'f' => 3 } } }
      expect(described_class.nest_configs(input)).to eq(expected)
    end

    it 'merges keys with common prefixes' do
      input = { 'a.b' => 1, 'a.c' => 2 }
      expected = { 'a' => { 'b' => 1, 'c' => 2 } }
      expect(described_class.nest_configs(input)).to eq(expected)
    end

    it 'recursively unnests hashes within values' do
      input = {
        'top' => 1,
        'nested' => { 'a.b' => 2, 'c' => 3 },
        'deep.nest' => { 'x.y' => 4 }
      }
      expected = {
        'top' => 1,
        'nested' => { 'a' => { 'b' => 2 }, 'c' => 3 },
        'deep' => { 'nest' => { 'x' => { 'y' => 4 } } }
      }
      expect(described_class.nest_configs(input)).to eq(expected)
    end
  end
end
