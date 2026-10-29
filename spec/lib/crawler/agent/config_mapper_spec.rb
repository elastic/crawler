#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'base64'

RSpec.describe(Crawler::Agent::ConfigMapper) do
  let(:logger) { instance_double(Crawler::Logging::CrawlLogger, warn: nil) }

  let(:input_source) do
    {
      'id' => 'crawler-1', 'type' => 'crawler', 'name' => 'My crawler', 'revision' => 3, 'use_output' => 'default',
      'data_stream' => { 'namespace' => 'default' }, 'meta' => { 'package' => { 'name' => 'crawler' } },
      'streams' => [],
      'domains' => [{ 'url' => 'https://example.com', 'seed_urls' => ['https://example.com/go'] }],
      'output_index' => 'search-web',
      'schedule' => { 'pattern' => '0 * * * *' },
      'max_crawl_depth' => 3,
      'elasticsearch.pipeline' => 'my-pipeline'
    }
  end

  let(:output_source) do
    {
      'type' => 'elasticsearch', 'hosts' => ['https://es.example.com:9243'], 'api_key' => 'id:secret',
      'preset' => 'balanced', 'ssl' => { 'verification_mode' => 'full' }
    }
  end

  def unit(type, source, log_level: :INFO)
    Crawler::Agent::Unit.new(
      id: "#{type}-1", type:, state: :HEALTHY, config_state_idx: 1, log_level:,
      config: { type: source['type'], source: }
    )
  end

  describe '.crawl_params' do
    subject(:params) do
      described_class.crawl_params(input: unit(:INPUT, input_source), output: unit(:OUTPUT, output_source), logger:)
    end

    it 'maps the input unit to crawler settings and drops policy bookkeeping keys' do
      expect(params).to include(
        domains: [{ url: 'https://example.com', seed_urls: ['https://example.com/go'] }],
        output_index: 'search-web',
        output_sink: 'elasticsearch',
        schedule: { pattern: '0 * * * *' },
        max_crawl_depth: 3,
        log_level: 'info'
      )
      expect(params.keys).not_to include(:id, :type, :name, :revision, :use_output, :data_stream, :meta, :streams)
    end

    it 'maps the output unit to Elasticsearch settings, keeping input-level overrides' do
      expect(params[:elasticsearch]).to eq(
        host: 'https://es.example.com:9243',
        api_key: Base64.strict_encode64('id:secret'),
        pipeline: 'my-pipeline'
      )
    end

    it 'produces a valid crawler configuration' do
      config = Crawler::API::Config.new(**params)
      expect(config.domain_allowlist.map(&:to_s)).to eq(['https://example.com:443'])
      expect(config.elasticsearch[:host]).to eq('https://es.example.com:9243')
    end

    it 'warns about and drops unsupported settings' do
      input_source['bogus_setting'] = 1
      expect(logger).to receive(:warn).with(/Ignoring unsupported crawler settings.*bogus_setting/)
      expect(params).not_to have_key(:bogus_setting)
    end

    it 'derives the log level from the unit when the policy does not set one' do
      params = described_class.crawl_params(
        input: unit(:INPUT, input_source, log_level: :TRACE), output: unit(:OUTPUT, output_source), logger:
      )
      expect(params[:log_level]).to eq('debug')
    end

    it 'keeps an explicit log level from the policy' do
      input_source['log_level'] = 'warn'
      expect(params[:log_level]).to eq('warn')
    end

    it 'requires an output index for Elasticsearch sinks' do
      input_source.delete('output_index')
      expect { params }.to raise_error(Crawler::Agent::Error, /output_index is required/)
    end

    it 'does not require an output index for other sinks' do
      input_source.delete('output_index')
      input_source['output_sink'] = 'console'
      expect(params[:output_sink]).to eq('console')
    end
  end

  describe '.elasticsearch_params' do
    it 'uses the first host and adds a scheme when missing' do
      expect(described_class.elasticsearch_params('hosts' => ['es:9200', 'other:9200'])).to eq(host: 'http://es:9200'.to_s)
        .or eq('host' => 'http://es:9200')
    end

    it 'accepts a single host string' do
      expect(described_class.elasticsearch_params('hosts' => 'https://es:9200')).to eq('host' => 'https://es:9200')
    end

    it 'passes through already encoded api keys' do
      expect(described_class.elasticsearch_params('hosts' => ['http://es'],
                                                  'api_key' => 'encoded')).to include('api_key' => 'encoded')
    end

    it 'maps basic auth credentials' do
      result = described_class.elasticsearch_params('hosts' => ['http://es'], 'username' => 'elastic',
                                                    'password' => 'pw')
      expect(result).to include('username' => 'elastic', 'password' => 'pw')
      expect(result).not_to have_key('api_key')
    end

    it 'disables ssl verification when the output verification mode is none' do
      result = described_class.elasticsearch_params('hosts' => ['https://es'],
                                                    'ssl' => { 'verification_mode' => 'none' })
      expect(result).to include('ssl_verify' => false)
    end

    it 'writes inline certificate authorities to a file' do
      pem = "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----"
      result = described_class.elasticsearch_params('hosts' => ['https://es'],
                                                    'ssl' => { 'certificate_authorities' => [pem] })
      expect(File.read(result['ca_file'])).to eq(pem)
    end

    it 'fails without hosts' do
      expect { described_class.elasticsearch_params({}) }.to raise_error(described_class::OutputConfigError, /no hosts/)
    end

    it 'fails when a certificate authority file cannot be read' do
      expect { described_class.elasticsearch_params('hosts' => ['https://es'], 'ssl' => { 'certificate_authorities' => ['/nope.pem'] }) }
        .to raise_error(described_class::OutputConfigError, /certificate authorities/)
    end
  end
end
