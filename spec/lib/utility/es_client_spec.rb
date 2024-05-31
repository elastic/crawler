#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'elasticsearch'

RSpec.describe(Utility::EsClient) do
  let(:system_logger) { double }
  let(:host) { 'http://notreallyaserver' }
  let(:port) { '9200' }
  let(:elastic_product_headers) { { 'x-elastic-product': 'Elasticsearch'} }
  let(:config) do
    {
      elasticsearch: {
        username: 'user',
        password: 'pw',
        api_key: 'key',
        host:,
        port:
      }
    }.deep_symbolize_keys
  end

  let(:subject) { described_class.new(config[:elasticsearch], system_logger, '0.0.0-test', 'crawl-id') }

  before(:each) do
    stub_request(:get, "#{host}:#{port}/")
      .to_return(status: 403, body: '', headers: {})
    stub_request(:get, "#{host}:#{port}/_cluster/health")

    # TODO: make a factory or something for system_logger mocks
    allow(system_logger).to receive(:info)
    allow(system_logger).to receive(:debug)
    allow(system_logger).to receive(:warn)
  end

  describe '#connection_config' do
    context 'when ca_fingerprint is configured' do
      let(:ca_fingerprint) { '64F2593F...' }

      it 'configures Elasticsearch client with ca_fingerprint' do
        config[:elasticsearch][:ca_fingerprint] = ca_fingerprint
        # there is no other way to get ca_fingerprint variable
        expect(subject.instance_variable_get(:@transport).instance_variable_get(:@ca_fingerprint)).to eq(ca_fingerprint)
      end
    end

    context 'when API key is not present' do
      it 'initialises with username and password' do
        config[:elasticsearch][:api_key] = nil

        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')

        expect(result[:hosts]).to eq([{ host: 'notreallyaserver', user: 'user', password: 'pw', port: '9200',
                                        scheme: 'http' }])
        expect(result[:host]).to be_nil
        expect(result[:api_key]).to be_nil
        expect(result[:transport_options][:headers][:'user-agent']).to eq('elastic-web-crawler-0.0.0-foo')
      end
    end

    context 'when API key is present' do
      it 'overrides username and password' do
        result = subject.connection_config(config[:elasticsearch], '0.0.0-bar')

        expect(result[:hosts]).to be_nil
        expect(result[:host]).to eq("#{host}:#{port}")
        expect(result[:api_key]).to eq('key')
        expect(result[:transport_options][:headers][:'user-agent']).to eq('elastic-web-crawler-0.0.0-bar')
      end
    end

    xcontext 'when headers are present' do
      # TODO: implement when we support headers in config
      let(:headers) do
        {
          something: 'something'
        }
      end

      it 'configures Elasticsearch client with headers' do
        config[:elasticsearch]['headers'] = headers

        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')

        expect(result['headers']).to eq(headers)
      end
    end

    context 'when headers are not present' do
      it 'configures Elasticsearch client with no headers' do
        config[:elasticsearch][:headers] = nil

        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')

        expect(result).to_not have_key(:headers)
      end
    end
  end

  describe '#bulk' do
    let(:payload) do
      {
        body: [
          { index: { _index: 'my_index', _id: '123' } },
          { id: '123', title: 'Foo', body_content: 'bar' }
        ]
      }
    end

    context 'when successful' do
      before :each do
        stub_request(:post, "#{host}:#{port}/_bulk").to_return(status: 200, headers: elastic_product_headers)
      end

      it 'sends bulk request without error' do
        result = subject.bulk(payload)
        expect(result.status).to eq(200)
      end
    end

    context 'when there is an error in the first attempt' do
      before :each do
        stub_request(:post, "#{host}:#{port}/_bulk").to_return({ status: 404, exception: 'Intermittent failure' }, {status: 200, headers: elastic_product_headers})
      end

      it 'succeeds on the retry' do
        result = subject.bulk(payload)
        expect(result.status).to eq(200)
        expect(system_logger).to have_received(:info).with("Bulk index attempt 1 failed: 'Intermittent failure'. Retrying in 2 seconds...")
      end
    end

    context 'when there is an error in every attempt' do
      let(:fixed_time) { Time.new(2024, 1, 1, 0, 0, 0) }
      let(:file_double) { double("File", puts: nil, close: nil) }

      before :each do
        stub_const('Utility::EsClient::MAX_RETRIES', 1)
        allow(File).to receive(:open).and_yield(file_double)
        allow(Time).to receive(:now).and_return(fixed_time)
        stub_request(:post, "#{host}:#{port}/_bulk").to_return({ status: 404, exception: 'Consistent failure' })
      end

      it 'raises an error after exhausting retries' do
        expect { subject.bulk(payload) }.to raise_error(StandardError)

        expect(system_logger).to have_received(:info).with("Bulk index attempt 1 failed: 'Consistent failure'. Retrying in 2 seconds...")
        expect(system_logger).to have_received(:warn).with("Bulk index failed after 2 attempts: 'Consistent failure'. Writing payload to file...")

        expect(File).to have_received(:open).with("#{Utility::EsClient::FAILED_BULKS_DIR}/crawl-id/#{fixed_time.strftime('%Y%m%d%H%M%S')}", 'w')

        expect(file_double).to have_received(:puts).with(payload[:body].first)
        expect(file_double).to have_received(:puts).with(payload[:body].second)
      end
    end
  end
end
