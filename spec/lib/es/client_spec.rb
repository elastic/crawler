#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'elasticsearch'

RSpec.describe(ES::Client) do
  let(:system_logger) { double }
  let(:host) { 'http://notreallyaserver' }
  let(:port) { '9200' }
  let(:elastic_product_headers) { { 'x-elastic-product': 'Elasticsearch' } }
  let(:index_name) { 'fantastic_index_name' }
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

    context 'when compression setting is not present' do
      it 'defaults compression to true' do
        config[:elasticsearch].delete(:compression) # Ensure it's not set
        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')
        expect(result[:compression]).to be true
      end
    end

    context 'when compression setting is true' do
      it 'sets compression to true' do
        config[:elasticsearch][:compression] = true
        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')
        expect(result[:compression]).to be true
      end
    end

    context 'when compression setting is false' do
      it 'sets compression to false' do
        config[:elasticsearch][:compression] = false
        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')
        expect(result[:compression]).to be false
      end
    end
  end

  describe '#bulk' do
    let(:payload) do
      {
        body: [
          { index: { _index: index_name, _id: '123' } },
          { id: '123', title: 'Foo', body: 'bar' }
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
        stub_request(:post, "#{host}:#{port}/_bulk").to_return({ status: 404, exception: 'Intermittent failure' },
                                                               { status: 200, headers: elastic_product_headers })
      end

      it 'succeeds on the retry' do
        result = subject.bulk(payload)
        expect(result.status).to eq(200)
        expect(system_logger).to have_received(:info).with(
          "Bulk index attempt 1 failed: 'Intermittent failure'. Retrying in 2 seconds..."
        )
      end
    end

    context 'when there is an error in every attempt' do
      let(:fixed_time) { Time.new(2024, 1, 1, 0, 0, 0) }
      let(:file_double) { double('File', puts: nil, close: nil) }

      before :each do
        stub_const('ES::Client::MAX_RETRIES', 1)
        allow(File).to receive(:open).and_yield(file_double)
        allow(Time).to receive(:now).and_return(fixed_time)
        stub_request(:post, "#{host}:#{port}/_bulk").to_return({ status: 404, exception: 'Consistent failure' })
      end

      it 'raises an error after exhausting retries' do
        expect { subject.bulk(payload) }.to raise_error(StandardError)

        expect(system_logger).to have_received(:info).with(
          "Bulk index attempt 1 failed: 'Consistent failure'. Retrying in 2 seconds..."
        )
        expect(system_logger).to have_received(:warn).with(
          "Bulk index failed after 2 attempts: 'Consistent failure'. Writing payload to file..."
        )

        expect(File).to have_received(:open).with(
          "#{ES::Client::FAILED_BULKS_DIR}/crawl-id/#{fixed_time.strftime('%Y%m%d%H%M%S')}", 'w'
        )

        expect(file_double).to have_received(:puts).with(payload[:body].first)
        expect(file_double).to have_received(:puts).with(payload[:body].second)
      end
    end
  end

  describe '#paginated_search' do
    let(:size) { Crawler::OutputSink::Elasticsearch::SEARCH_PAGINATION_SIZE }
    let(:query) do
      {
        _source: ['url'],
        query: {
          range: {
            last_crawled_at: {
              lt: Time.now.rfc3339
            }
          }
        },
        size:,
        sort: [{ last_crawled_at: 'asc' }]
      }.deep_stringify_keys
    end

    let(:hit1) do
      {
        _id: '1234',
        _source: { url: 'https://www.elastic.co/search-labs' },
        sort: [1]
      }.deep_stringify_keys
    end
    let(:hit2) do
      {
        _id: '5678',
        _source: { url: 'https://www.elastic.co/search-labs/tutorials' },
        sort: [2]
      }.deep_stringify_keys
    end
    let(:empty_response) do
      {
        hits: {
          hits: []
        }
      }.deep_stringify_keys
    end
    let(:full_response) do
      {
        hits: {
          hits: [hit1, hit2]
        }
      }.deep_stringify_keys
    end

    context 'when successful' do
      before do
        allow(subject)
          .to receive(:search).and_return(full_response, empty_response)
      end

      it 'sends search requests without error' do
        expect(subject).to receive(:search).twice

        results = subject.paginated_search(index_name, query)
        expect(results).to match_array([hit1, hit2])
      end
    end

    context 'when successful with pagination' do
      let(:size) { 1 }

      let(:first_response) do
        {
          hits: {
            hits: [hit1]
          }
        }.deep_stringify_keys
      end
      let(:second_response) do
        {
          hits: {
            hits: [hit2]
          }
        }.deep_stringify_keys
      end

      before do
        allow(subject)
          .to receive(:search).and_return(first_response, second_response, empty_response)
      end

      it 'sends search requests without error' do
        expect(subject).to receive(:search).exactly(3).times

        results = subject.paginated_search(index_name, query)
        expect(results).to match_array([hit1, hit2])
      end
    end

    context 'when one request fails' do
      before do
        call_count = 0
        allow(subject).to receive(:search) do
          call_count += 1

          case call_count
          when 1 then raise StandardError('oops')
          when 2 then full_response
          else
            empty_response
          end
        end
      end

      it 'sends search requests without error' do
        expect(subject).to receive(:search).exactly(3).times

        results = subject.paginated_search(index_name, query)
        expect(results).to match_array([hit1, hit2])
      end
    end

    context 'when all requests fails' do
      before do
        stub_const('ES::Client::MAX_RETRIES', 1)
        allow(subject).to receive(:search).and_raise(StandardError.new('big oops'))
      end

      it 'raises an error after retrying' do
        expect(subject).to receive(:search).exactly(2).times

        expect { subject.paginated_search(index_name, query) }.to raise_error(StandardError, 'big oops')
      end
    end
  end
end
