#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'elasticsearch'

require 'elastic/transport/transport/errors'
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
    allow(system_logger).to receive(:error)
  end

  describe 'retry configuration' do
    context 'with default settings' do
      let(:config) { { elasticsearch: { host:, port: } } }

      it 'sets default retry values' do
        expect(subject.instance_variable_get(:@max_retries)).to eq(3)
        expect(subject.instance_variable_get(:@retry_delay)).to eq(2)
        expect(system_logger).to have_received(:debug).with(
          'Elasticsearch client retry configuration: 3 retries with 2s delay'
        )
      end
    end

    context 'with custom retry settings' do
      let(:config) { { elasticsearch: { host:, port:, retry_on_failure: 5, delay_on_retry: 1 } } }

      it 'sets custom retry values' do
        expect(subject.instance_variable_get(:@max_retries)).to eq(5)
        expect(subject.instance_variable_get(:@retry_delay)).to eq(1)
        expect(system_logger).to have_received(:debug).with(
          'Elasticsearch client retry configuration: 5 retries with 1s delay'
        )
      end
    end

    context 'with retry_on_failure: true' do
      let(:config) { { elasticsearch: { host:, port:, retry_on_failure: true } } }

      it 'sets default retry count' do
        expect(subject.instance_variable_get(:@max_retries)).to eq(3)
        expect(system_logger).to have_received(:debug).with(
          'Elasticsearch client retry configuration: 3 retries with 2s delay'
        )
      end
    end

    context 'with retry_on_failure: false' do
      let(:config) { { elasticsearch: { host:, port:, retry_on_failure: false } } }

      it 'sets zero retries' do
        expect(subject.instance_variable_get(:@max_retries)).to eq(0)
        expect(system_logger).to have_received(:debug).with(
          'Elasticsearch client retry configuration: 0 retries with 2s delay'
        )
      end
    end

    context 'with invalid retry_on_failure' do
      let(:config) { { elasticsearch: { host:, port:, retry_on_failure: 'invalid' } } }

      it 'sets default retry count' do
        expect(subject.instance_variable_get(:@max_retries)).to eq(3)
        expect(system_logger).to have_received(:debug).with(
          'Elasticsearch client retry configuration: 3 retries with 2s delay'
        )
      end
    end

    context 'with invalid delay_on_retry' do
      let(:config) { { elasticsearch: { host:, port:, delay_on_retry: 'invalid' } } }

      it 'sets default retry delay' do
        expect(subject.instance_variable_get(:@retry_delay)).to eq(2)
        expect(system_logger).to have_received(:debug).with(
          'Elasticsearch client retry configuration: 3 retries with 2s delay'
        )
      end
    end
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

    context 'when retrying bulk requests' do
      let(:bulk_url) { "#{host}:#{port}/_bulk" }

      let(:error_response) do
        { status: 500, body: '{"error":"boom"}', headers: { 'Content-Type' => 'application/json' } }
      end
      let(:success_response) do
        { status: 200, headers: elastic_product_headers }
      end
      context 'when there is an error in the first attempt' do
        let(:config) do
          {
            elasticsearch: {
              host:, port:, retry_on_failure: 2, delay_on_retry: 3
            }
          }.deep_symbolize_keys
        end

        before :each do
          stub_request(:post, bulk_url)
            .to_return(error_response) # Attempt 1 fails
            .then.to_return(success_response) # Attempt 2 succeeds
        end

        it 'succeeds on the retry and logs the attempt' do
          expect(subject).to receive(:sleep).with(3**1).once
          result = subject.bulk(payload)
          expect(result.status).to eq(200)
          expect(system_logger).to have_received(:warn).with(
            %r{Bulk index attempt 1/3 failed: '\[500\] {"error":"boom"}'. Retrying in 3\.0s..}
          )
        end
      end

      context 'when there is an error in every attempt' do
        let(:config) do
          {
            elasticsearch: {
              host:, port:, retry_on_failure: 1, delay_on_retry: 1
            }
          }.deep_symbolize_keys
        end

        before :each do
          stub_request(:post, bulk_url).to_return(error_response)
        end

        it 'raises an error, logs attempts, and saves payload' do
          file_double = double('File', puts: nil, close: nil)
          expect(File).to receive(:open).with(%r{output/failed_payloads/crawl-id/\d{14}}, 'w').and_yield(file_double)

          expect(subject).to receive(:sleep).with(1**1).once

          expect do
            subject.bulk(payload)
          end.to raise_error(Elastic::Transport::Transport::ServerError, /\[500\] {"error":"boom"}/)

          expect(system_logger).to have_received(:warn).with(
            %r{Bulk index attempt 1/2 failed: '\[500\] {"error":"boom"}'. Retrying in 1\.0s..}
          )

          expect(system_logger).to have_received(:error).with(
            /Bulk index failed after 2 attempts: '\[500\] {"error":"boom"}'/
          )

          expect(file_double).to have_received(:puts).with(payload[:body].first)
          expect(file_double).to have_received(:puts).with(payload[:body].second)
        end

        context 'with retries disabled' do
          let(:config) do
            {
              elasticsearch: {
                host:, port:, retry_on_failure: false # Disable retries
              }
            }.deep_symbolize_keys
          end

          it 'fails immediately, logs final failure, and saves payload' do
            file_double = double('File', puts: nil, close: nil)
            expect(File).to receive(:open).with(%r{output/failed_payloads/crawl-id/\d{14}}, 'w').and_yield(file_double)

            expect(subject).not_to receive(:sleep)

            expect do
              subject.bulk(payload)
            end.to raise_error(Elastic::Transport::Transport::ServerError, /\[500\] {"error":"boom"}/)
            expect(system_logger).not_to have_received(:warn).with(/Bulk index attempt/)

            expect(system_logger).to have_received(:error).with(
              /Bulk index failed: '\[500\] {"error":"boom"}'. Retries disabled./
            )

            expect(file_double).to have_received(:puts).with(payload[:body].first)
            expect(file_double).to have_received(:puts).with(payload[:body].second)
          end
        end
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

    context 'when retrying paginated search requests' do
      let(:search_url) { %r{#{host}:#{port}/#{index_name}/_search} }

      let(:error_response) do
        { status: 503, body: '{"error":"unavailable"}', headers: { 'Content-Type' => 'application/json' } }
      end
      # Add elastic_product_headers to successful responses
      let(:success_response_page1) do
        { status: 200, body: full_response.to_json,
          headers: elastic_product_headers.merge('Content-Type' => 'application/json') }
      end
      let(:success_response_page2) do
        { status: 200, body: empty_response.to_json,
          headers: elastic_product_headers.merge('Content-Type' => 'application/json') }
      end

      context 'when the first search request fails once' do
        let(:config) do
          {
            elasticsearch: {
              host:, port:, retry_on_failure: 3, delay_on_retry: 2
            }
          }.deep_symbolize_keys
        end

        before do
          stub_request(:post, search_url)
            .to_return(error_response)
            .then.to_return(success_response_page1)
            .then.to_return(success_response_page2)
        end

        it 'retries, logs the attempt, and returns results' do
          expect(subject).to receive(:sleep).with(2**1).once

          results = subject.paginated_search(index_name, query)

          expect(results).to match_array([hit1, hit2])

          expect(system_logger).to have_received(:warn).with(
            %r{Search attempt 1/4 failed: '\[503\] {"error":"unavailable"}'. Retrying in 2\.0s..}
          )
        end
      end

      context 'when all search requests fail' do
        let(:config) do
          {
            elasticsearch: {
              host:, port:, retry_on_failure: 1, delay_on_retry: 1
            }
          }.deep_symbolize_keys
        end

        before do
          stub_request(:post, search_url).to_return(error_response)
        end

        it 'raises an error after exhausting retries and logs attempts' do
          expect(subject).to receive(:sleep).with(1**1).once

          expect do
            subject.paginated_search(index_name, query)
          end.to raise_error(StandardError, /\[503\] {"error":"unavailable"}/)
          expect(system_logger).to have_received(:warn).with(
            %r{Search attempt 1/2 failed: '\[503\] {"error":"unavailable"}'. Retrying in 1\.0s..}
          )

          expect(system_logger).to have_received(:error).with(
            /Search failed after 2 attempts: '\[503\] {"error":"unavailable"}'/
          )
        end
      end
    end
  end

  describe '#delete_by_query' do
    let(:delete_url) { %r{#{host}:#{port}/#{index_name}/_delete_by_query} }
    let(:query) { { query: { match_all: {} } } }

    let(:error_response) do
      { status: 500, body: '{"error":"delete_failed"}', headers: { 'Content-Type' => 'application/json' } }
    end

    let(:success_response) do
      { status: 200, body: '{"deleted": 10}',
        headers: elastic_product_headers.merge('Content-Type' => 'application/json') }
    end

    context 'when retrying delete_by_query requests' do
      let(:config) do
        {
          elasticsearch: {
            host:, port:, retry_on_failure: 1, delay_on_retry: 1
          }
        }.deep_symbolize_keys
      end

      context 'when the first attempt fails' do
        before do
          stub_request(:post, delete_url)
            .to_return(error_response) # Attempt 1 fails
            .then.to_return(success_response) # Attempt 2 succeeds
        end

        it 'succeeds on the retry and logs the attempt' do
          expect(subject).to receive(:sleep).with(1**1).once

          expect { subject.delete_by_query(index: index_name, body: query) }.not_to raise_error

          expect(system_logger).to have_received(:warn).with(
            %r{Delete by query attempt 1/2 failed: '\[500\] {"error":"delete_failed"}'. Retrying in 1\.0s..}
          )
        end
      end

      context 'when all attempts fail' do
        before do
          stub_request(:post, delete_url).to_return(error_response) # Always fail
        end

        it 'raises an error after exhausting retries and logs attempts' do
          expect(subject).to receive(:sleep).with(1**1).once

          expect do
            subject.delete_by_query(index: index_name, body: query)
          end.to raise_error(Elastic::Transport::Transport::ServerError, /\[500\] {"error":"delete_failed"}/)

          expect(system_logger).to have_received(:warn).with(
            %r{Delete by query attempt 1/2 failed: '\[500\] {"error":"delete_failed"}'. Retrying in 1\.0s..}
          )

          expect(system_logger).to have_received(:error).with(
            /Delete by query failed after 2 attempts: '\[500\] {"error":"delete_failed"}'/
          )
        end
      end
    end
  end
end
