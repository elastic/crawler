#
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

    it 'loads plain YAML without ERB' do
      tmpfile.write("---\nfoo: bar\nbaz: 1\n")
      tmpfile.rewind
      result = described_class.load_yaml(tmpfile.path)
      expect(result).to eq({ 'foo' => 'bar', 'baz' => 1 })
    end

    it 'loads YAML with ERB environment variable interpolation' do
      ENV['TEST_ENV_VAR'] = 'secret'
      tmpfile.write("---\napi_key: <%= ENV['TEST_ENV_VAR'] %>\n")
      tmpfile.rewind
      result = described_class.load_yaml(tmpfile.path)
      expect(result).to eq({ 'api_key' => 'secret' })
    end

    it 'loads YAML with ERB and Ruby default logic' do
      ENV.delete('MISSING_ENV_VAR')
      tmpfile.write("---\nvalue: <%= ENV['MISSING_ENV_VAR'] || 'default_value' %>\n")
      tmpfile.rewind
      result = described_class.load_yaml(tmpfile.path)
      expect(result).to eq({ 'value' => 'default_value' })
    end

    it 'raises error for invalid ERB syntax' do
      tmpfile.write("---\nfoo: <%= %invalid ruby %>\n")
      tmpfile.rewind
      expect do
        described_class.load_yaml(tmpfile.path)
      end.to raise_error(SyntaxError)
    end

    it 'raises error for invalid YAML after ERB' do
      tmpfile.write("---\nfoo: <%= 1 + %>\n")
      tmpfile.rewind
      expect do
        described_class.load_yaml(tmpfile.path)
      end.to raise_error(SyntaxError)

    let(:path) { tmpfile.path }

    after { tmpfile.close! }

    context 'when loading valid YAML' do
      subject(:loaded_yaml) { described_class.load_yaml(path) }

      it 'loads YAML content from a file path' do
        yaml_content = { 'key' => 'value', 'nested' => { 'subkey' => 123 } }
        tmpfile.write(YAML.dump(yaml_content))
        tmpfile.rewind
        expect(loaded_yaml).to eq(yaml_content)
      end

      it 'returns nil if the file is empty' do
        tmpfile.write('')
        tmpfile.rewind
        expect(loaded_yaml).to be_nil
      end
    end

    context 'when encountering errors' do
      subject(:load_action) { described_class.load_yaml(path) }

      context 'when the file does not exist' do
        # Override path for this specific context
        let(:path) { '/path/to/non/existent/file.yml' }

        it 'exits' do
          allow(described_class).to receive(:puts) # Prevent noise during test.
          expect { load_action }.to raise_error(SystemExit)
        end
      end

      context 'when the YAML syntax is invalid' do
        before do
          tmpfile.write('key: [unclosed')
          tmpfile.rewind

          allow(described_class).to receive(:puts) # Prevent noise during test.
        end

        it 'exits' do
          expect { load_action }.to raise_error(SystemExit)
        end
      end
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

    RSpec.shared_examples 'loads crawl configuration correctly' do
      it 'generates a new Config instance' do
        expect(described_class.load_crawl_config(crawl_fixture, es_fixture)).to eq(crawl_configuration)
      end
    end

    context 'when given just a crawl config' do
      let(:crawl_fixture) { crawl_config_fixture }
      let(:es_fixture) { nil }
      include_examples 'loads crawl configuration correctly'
    end

    context 'when given a crawl and elasticsearch config' do
      context 'with nested YAML' do
        let(:crawl_fixture) { crawl_config_fixture }
        let(:es_fixture) { es_config_fixture }
        include_examples 'loads crawl configuration correctly'
      end

      context 'with flat YAML' do
        let(:crawl_fixture) { crawl_config_fixture }
        let(:es_fixture) { es_config_flat_fixture }
        include_examples 'loads crawl configuration correctly'
      end

      context 'with YAML of mixed-flatness' do
        let(:crawl_fixture) { crawl_config_fixture }
        let(:es_fixture) { es_config_partially_flat_fixture }
        include_examples 'loads crawl configuration correctly'
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

  describe '.dedot_hash' do
    subject(:dedotted_hash) { described_class.dedot_hash(input) }

    context 'with nil input' do
      let(:input) { nil }
      let(:expected) { {} }
      it { is_expected.to eq(expected) }
    end

    context 'with empty hash input' do
      let(:input) { {} }
      let(:expected) { {} }
      it { is_expected.to eq(expected) }
    end

    context 'with simple dot notation keys' do
      let(:input) { { 'a.b' => 1, 'c.d' => 2 } }
      let(:expected) { { 'a' => { 'b' => 1 }, 'c' => { 'd' => 2 } } }
      it { is_expected.to eq(expected) }
    end

    context 'with multiple levels of dot notation' do
      let(:input) { { 'a.b.c' => 1, 'x.y.z' => 'hello' } }
      let(:expected) { { 'a' => { 'b' => { 'c' => 1 } }, 'x' => { 'y' => { 'z' => 'hello' } } } }
      it { is_expected.to eq(expected) }
    end

    context 'with mixed dot notation and regular keys' do
      let(:input) { { 'a.b' => 1, 'c' => 2, 'd.e.f' => 3 } }
      let(:expected) { { 'a' => { 'b' => 1 }, 'c' => 2, 'd' => { 'e' => { 'f' => 3 } } } }
      it { is_expected.to eq(expected) }
    end

    context 'when merging keys with common prefixes' do
      let(:input) { { 'a.b' => 1, 'a.c' => 2 } }
      let(:expected) { { 'a' => { 'b' => 1, 'c' => 2 } } }
      it { is_expected.to eq(expected) }
    end

    context 'when recursively unnesting hashes within values' do
      let(:input) do
        {
          'top' => 1,
          'nested' => { 'a.b' => 2, 'c' => 3 },
          'deep.nest' => { 'x.y' => 4 }
        }
      end
      let(:expected) do
        {
          'top' => 1,
          'nested' => { 'a' => { 'b' => 2 }, 'c' => 3 },
          'deep' => { 'nest' => { 'x' => { 'y' => 4 } } }
        }
      end
      it { is_expected.to eq(expected) }
    end
  end
end
