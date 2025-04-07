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

  describe '#initialize' do
    context 'when configuring retries' do
      it 'defaults retry configuration when retry_on_failure is not set' do
        expected_config = { retry_on_failure: 3, retry_on_status: ES::Client::DEFAULT_RERTY_ON_STATUS,
                            delay_on_retry: ES::Client::DEFAULT_DELAY_ON_RETRY, reload_on_failure: false }
        expect(system_logger).to have_received(:debug).with(
          "Elasticsearch client retry configuration: #{expected_config}"
        )
      end

      it 'sets retry_on_failure to 3 in config when retry_on_failure is true' do
        config[:elasticsearch][:retry_on_failure] = true

        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')
        expect(result[:retry_on_failure]).to eq(3)
      end

      it 'sets retry_on_failure to 3 in config when retry_on_failure is invalid' do
        config[:elasticsearch][:retry_on_failure] = 'Popovers'
        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')
        expect(result[:retry_on_failure]).to eq(3)
      end

      it 'sets retry_on_failure to the specified integer in config when retry_on_failure is a positive integer' do
        config[:elasticsearch][:retry_on_failure] = 5
        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')
        expect(result[:retry_on_failure]).to eq(5)
      end

      it 'sets retry_on_failure to 0 in config when retry_on_failure is false' do
        config[:elasticsearch][:retry_on_failure] = false
        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')
        expect(result[:retry_on_failure]).to eq(0)
      end

      it 'sets retry_on_failure to 0 in config when retry_on_failure is 0' do
        config[:elasticsearch][:retry_on_failure] = 0
        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')
        expect(result[:retry_on_failure]).to eq(0)
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

    context 'with request_timeout configuration' do
      it 'uses the default timeout if not specified' do
        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')

        expect(result[:request_timeout]).to eq(ES::Client::DEFAULT_REQUEST_TIMEOUT)
        expect(result.dig(:transport_options, :request, :timeout)).to eq(ES::Client::DEFAULT_REQUEST_TIMEOUT)
      end

      it 'uses the specified timeout from config' do
        config[:elasticsearch][:request_timeout] = 30

        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')

        expect(result[:request_timeout]).to eq(30)
        expect(result.dig(:transport_options, :request, :timeout)).to eq(30)
      end
    end

    context 'with reload_on_failure configuration' do
      it 'uses the default reload_on_failure if not specified' do
        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')
        expect(result[:reload_on_failure]).to be(false)
      end

      it 'uses the specified reload_on_failure from config' do
        config[:elasticsearch][:reload_on_failure] = true

        result = subject.connection_config(config[:elasticsearch], '0.0.0-test')

        expect(result[:reload_on_failure]).to be(true)
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
      before do
        # Simulate a successful response with no 'errors' key
        stub_request(:post, "#{host}:#{port}/_bulk")
          .to_return(status: 200, body: { errors: false, items: [] }.to_json, headers: elastic_product_headers)
      end

      it 'sends bulk request without error' do
        response = subject.bulk(payload)
        expect(response['errors']).to eq(false)
      end
    end

    context 'when first try has a transport error and second try succeeds' do
      let(:success_body) { { errors: false, items: [] }.to_json }

      before do
        stub_request(:post, "#{host}:#{port}/_bulk")
          .to_return({ status: 503, body: 'Service Unavailable' }, # Status configured in DEFAULT_RERTY_ON_STATUS
                     { status: 200, body: success_body, headers: elastic_product_headers })
      end

      it 'succeeds on the retry and logs transport warning' do
        response = subject.bulk(payload)
        expect(response['errors']).to eq(false)

        expect(a_request(:post, "#{host}:#{port}/_bulk")).to have_been_made.times(2)

        # Check for the transport layer's retry warning log
        expect(system_logger).to have_received(:warn).with(
          /Attempt \d+ failed with Elasticsearch::Transport::Transport::Errors::ServiceUnavailable.+Retrying/
        )
      end
    end

    context 'when the bulk response contains errors' do
      let(:error_response_body) do
        {
          errors: true,
          items: [
            { index: { _index: index_name, _id: '123', status: 400,
                       error: { type: 'mapper_parsing_exception', reason: 'failed to parse' } } }
          ]
        }.to_json
      end
      let(:first_error_item) { JSON.parse(error_response_body)['items'].first }

      before do
        stub_request(:post, "#{host}:#{port}/_bulk")
          .to_return(status: 200, body: error_response_body, headers: elastic_product_headers)
      end

      it 'raises IndexingFailedError and logs response warning' do
        expect { subject.bulk(payload) }
          .to raise_error(ES::Client::IndexingFailedError,
                          /Failed to index documents into Elasticsearch with an error '#{first_error_item.to_json}'/)

        # Item-level errors are not retried automatically
        expect(a_request(:post, "#{host}:#{port}/_bulk")).to have_been_made.times(1)

        expect(system_logger).to have_received(:warn).with(/Errors found in bulk response. Full response: .+/)

        # Ensure payload is NOT stored in this case
        expect(File).not_to have_received(:open)
      end
    end

    context 'when a transport error occurs on every attempt' do
      let(:fixed_time) { Time.new(2024, 1, 1, 0, 0, 0) }
      let(:file_double) { instance_double('File', puts: nil, close: nil) }
      let(:expected_failure_path) { "#{ES::Client::FAILED_BULKS_DIR}/crawl-id/#{fixed_time.strftime('%Y%m%d%H%M%S')}" }

      before do
        config[:elasticsearch][:retry_on_failure] = 1

        subject

        allow(File).to receive(:open).with(expected_failure_path, 'w').and_yield(file_double)
        allow(FileUtils).to receive(:mkdir_p)
        allow(Time).to receive(:now).and_return(fixed_time)

        stub_request(:post, "#{host}:#{port}/_bulk").to_return(status: 503, body: 'Consistent failure')
      end

      it 'raises the transport error, logs details, and stores the payload' do
        expect { subject.bulk(payload) }.to raise_error(Elasticsearch::Transport::Transport::Errors::ServiceUnavailable)

        expect(a_request(:post, "#{host}:#{port}/_bulk")).to have_been_made.times(2)

        expect(system_logger).to have_received(:error).with(
          "Bulk index failed: '503 Service Unavailable'. Storing payload."
        )

        expect(system_logger).to have_received(:warn).with("Saved failed bulk payload to #{expected_failure_path}")

        # Verify directory creation and file writing
        expect(FileUtils).to have_received(:mkdir_p).with("#{ES::Client::FAILED_BULKS_DIR}/crawl-id")
        expect(File).to have_received(:open).with(expected_failure_path, 'w')
        expect(file_double).to have_received(:puts).with(payload[:body].first).ordered
        expect(file_double).to have_received(:puts).with(payload[:body].second).ordered
      end
    end

    context 'when retries are disabled' do
      let(:file_double) { instance_double('File', puts: nil, close: nil) }
      let(:fixed_time) { Time.new(2024, 1, 1, 0, 0, 0) }
      let(:expected_failure_path) { "#{ES::Client::FAILED_BULKS_DIR}/crawl-id/#{fixed_time.strftime('%Y%m%d%H%M%S')}" }

      before do
        config[:elasticsearch][:retry_on_failure] = false

        subject

        allow(File).to receive(:open).with(expected_failure_path, 'w').and_yield(file_double)
        allow(FileUtils).to receive(:mkdir_p)
        allow(Time).to receive(:now).and_return(fixed_time)
        stub_request(:post, "#{host}:#{port}/_bulk").to_return(status: 500, body: 'Server Error')
      end

      it 'fails immediately, logs details, and stores the payload' do
        expect do
          subject.bulk(payload)
        end.to raise_error(Elasticsearch::Transport::Transport::Errors::InternalServerError)

        expect(a_request(:post, "#{host}:#{port}/_bulk")).to have_been_made.times(1)

        expect(system_logger).to have_received(:error).with(
          "Bulk index failed: '500 Internal Server Error'. Storing payload."
        )
        expect(system_logger).to have_received(:warn).with("Saved failed bulk payload to #{expected_failure_path}")

        expect(FileUtils).to have_received(:mkdir_p).with("#{ES::Client::FAILED_BULKS_DIR}/crawl-id")
        expect(File).to have_received(:open).with(expected_failure_path, 'w')
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

    context 'when the search call raises an error (rescue block behavior)' do
      before do
        call_count = 0
        allow(subject).to receive(:search) do |_args|
          call_count += 1
          # Pass through to original search implementation if needed, or mock responses
          case call_count
          when 1 then raise StandardError, 'search oops' # First call fails
          when 2 then full_response # Second call succeeds
          else
            empty_response # Subsequent calls are empty
          end
        end
      end

      it 'logs the error and continues pagination' do
        expect(subject).to receive(:search).exactly(3).times # Original call, successful retry, empty call

        results = subject.paginated_search(index_name, query)

        # Verify the error was logged
        expect(system_logger).to have_received(:error).with("Search failed: 'search oops'.")
        # Verify the final results are correct despite the initial error
        expect(results).to match_array([hit1, hit2])
      end
    end

    context 'when the search transport layer fails temporarily (transport retries)' do
      let(:search_url) { "#{host}:#{port}/#{index_name}/_search" }
      let(:success_body) { full_response.to_json }
      let(:empty_body) { empty_response.to_json }

      before do
        # Fail first time (status triggers retry), succeed second and third time
        stub_request(:post, search_url)
          .to_return(
            { status: 503, body: 'Service Unavailable' }, # Retryable error
            { status: 200, body: success_body, headers: elastic_product_headers },
            { status: 200, body: empty_body, headers: elastic_product_headers }
          )
        describe '#delete_by_query' do
          let(:delete_query_body) { { query: { match_all: {} } } }
          let(:delete_url) { "#{host}:#{port}/#{index_name}/_delete_by_query?refresh=true" } # Default refresh is true

          context 'when successful' do
            let(:success_response) { { 'took' => 10, 'deleted' => 5, 'failures' => [] } }

            before do
              # Stub the underlying client's method directly
              allow(subject).to receive(:delete_by_query).and_call_original # Ensure we call our wrapper
              allow(subject.transport).to receive(:perform_request)
                .with('POST', "#{index_name}/_delete_by_query", { refresh: true }, delete_query_body, {})
                .and_return(instance_double(Elasticsearch::Transport::Transport::Response, body: success_response))
            end

            it 'calls the underlying client and returns the response' do
              result = subject.delete_by_query(index: index_name, body: delete_query_body)
              expect(result.body).to eq(success_response) # Check the response body from the stub
              expect(system_logger).not_to have_received(:error)
            end
          end

          context 'when the underlying client raises an error (rescue block behavior)' do
            before do
              allow(subject).to receive(:delete_by_query).and_call_original
              allow(subject.transport).to receive(:perform_request)
                .and_raise(StandardError, 'delete oops')
            end

            it 'logs the error and re-raises the exception' do
              expect { subject.delete_by_query(index: index_name, body: delete_query_body) }
                .to raise_error(StandardError, 'delete oops')
              expect(system_logger).to have_received(:error).with("Delete by query failed: 'delete oops'.")
            end
          end

          context 'when the transport layer fails temporarily (transport retries)' do
            let(:success_response) { { 'took' => 10, 'deleted' => 5, 'failures' => [] } }

            before do
              stub_request(:post, delete_url).with(body: delete_query_body.to_json)
                                             .to_return(
                                               { status: 503, body: 'Service Unavailable' }, # Retryable error
                                               { status: 200, body: success_response.to_json,
                                                 headers: elastic_product_headers }
                                             )
            end

            it 'retries the request and returns success' do
              result = subject.delete_by_query(index: index_name, body: delete_query_body)
              expect(result.body).to eq(success_response) # Check the response body from the stub
              expect(a_request(:post, delete_url)).to have_been_made.times(2) # Original + 1 retry
              expect(system_logger).to have_received(:warn).with(
                /Attempt \d+ failed with Elasticsearch::Transport::Transport::Errors::ServiceUnavailable.+Retrying/
              )
              expect(system_logger).not_to have_received(:error)
            end
          end

          context 'when the transport layer fails definitively (transport retries exhausted)' do
            before do
              config[:elasticsearch][:retry_on_failure] = 1 # Configure 1 retry (2 attempts)
              subject # Re-initialize subject with new config
              stub_request(:post, delete_url).with(body: delete_query_body.to_json)
                                             .to_return(status: 503, body: 'Consistent failure')
            end

            it 'logs the error and raises the transport error' do
              expect { subject.delete_by_query(index: index_name, body: delete_query_body) }
                .to raise_error(Elasticsearch::Transport::Transport::Errors::ServiceUnavailable)

              expect(a_request(:post, delete_url)).to have_been_made.times(2) # Original + 1 retry
              # Verify the rescue block logged the final error before re-raising
              expect(system_logger).to have_received(:error).with("Delete by query failed: '503 Service Unavailable'.")
            end
          end
        end
      end

      it 'retries the request and returns results' do
        results = subject.paginated_search(index_name, query)

        # Verify the request was made three times (original + 1 retry for first page, 1 for second page)
        expect(a_request(:post, search_url)).to have_been_made.times(3)
        # Check transport layer logged a warning (adjust regex if needed for library version)
        expect(system_logger).to have_received(:warn).with(
          /Attempt \d+ failed with Elasticsearch::Transport::Transport::Errors::ServiceUnavailable.+Retrying/
        )
        # Verify final results
        expect(results).to match_array([hit1, hit2])
      end
    end

    context 'when the search transport layer fails definitively (transport retries exhausted)' do
      let(:search_url) { "#{host}:#{port}/#{index_name}/_search" }

      before do
        # Configure client for only 1 retry (2 attempts total)
        config[:elasticsearch][:retry_on_failure] = 1
        # Re-initialize subject with updated config
        subject
        # Stub request to consistently fail
        stub_request(:post, search_url).to_return(status: 503, body: 'Consistent failure')
      end

      it 'logs the error and raises the transport error' do
        # Expect the final transport error after retries
        expect { subject.paginated_search(index_name, query) }
          .to raise_error(Elasticsearch::Transport::Transport::Errors::ServiceUnavailable)

        # Verify the request was made twice (original + 1 retry)
        expect(a_request(:post, search_url)).to have_been_made.times(2)

        # Verify the rescue block logged the final error before re-raising
        expect(system_logger).to have_received(:error).with("Search failed: '503 Service Unavailable'.")
      end
    end
  end
end
