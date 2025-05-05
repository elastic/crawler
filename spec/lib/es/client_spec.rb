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
        host: 'http://notreallyaserver',
        port: '9200'
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
    context 'when configuring Elasticsearch client' do
      it 'handles full URL with scheme, host and port' do
        new_config = {
          host: 'https://localhost:9201'
        }

        result = subject.connection_config(new_config, '0.0.0-foo')
        expect(result[:scheme]).to eq('https')
        expect(result[:host]).to eq('localhost')
        expect(result[:port]).to eq(9201)
      end

      it 'handles URL with scheme and host' do
        new_config = {
          host: 'https://localhost'
        }

        result = subject.connection_config(new_config, '0.0.0-foo')
        expect(result[:scheme]).to eq('https')
        expect(result[:host]).to eq('localhost')
      end

      it 'handles host with port' do
        new_config = {
          host: 'localhost',
          port: 9201
        }

        result = subject.connection_config(new_config, '0.0.0-foo')
        expect(result[:scheme]).to be_nil
        expect(result[:host]).to eq('localhost')
        expect(result[:port]).to eq(9201)
      end

      it 'handles host only' do
        new_config = {
          host: 'localhost'
        }

        result = subject.connection_config(new_config, '0.0.0-foo')
        expect(result[:scheme]).to be_nil
        expect(result[:host]).to eq('localhost')
        expect(result[:port]).to be_nil
      end

      it 'gives precedence to separate port over port in host' do
        new_config = {
          host: 'https://localhost:9201',
          port: 9300
        }

        result = subject.connection_config(new_config, '0.0.0-foo')
        expect(result[:port]).to eq(9300)
      end
    end

    context 'when ssl verification is not fully enabled' do
      it 'configures Elasticsearch client with ssl verification disabled' do
        config[:elasticsearch][:ssl_verify] = false

        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')

        expect(result[:transport_options][:ssl][:verify]).to eq(false)

        expect(result[:transport_options][:ssl][:ca_path]).to be_nil
        expect(result[:transport_options][:ssl][:ca_fingerprint]).to be_nil
      end
    end

    context 'when ca_file is configured' do
      let(:ca_file) { '/my/local/certificate.crt' }

      it 'configures Elasticsearch client with ca_file' do
        config[:elasticsearch][:ca_file] = ca_file

        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')

        expect(result[:transport_options][:ssl][:ca_file]).to eq(ca_file)
      end
    end

    context 'when ca_path is configured' do
      let(:ca_path) { '/my/local/certificates' }

      it 'configures Elasticsearch client with ca_path' do
        config[:elasticsearch][:ca_path] = ca_path

        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')

        expect(result[:transport_options][:ssl][:ca_path]).to eq(ca_path)
      end
    end

    context 'when ca_fingerprint is configured' do
      let(:ca_fingerprint) { '64F2593F...' }

      it 'configures Elasticsearch client with ca_fingerprint' do
        config[:elasticsearch][:ca_fingerprint] = ca_fingerprint

        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')

        expect(result[:ca_fingerprint]).to eq(ca_fingerprint)

        # Also ensure that SSL Verification has not been implicitly disabled
        expect(result[:transport_options][:ssl][:verify]).to be_nil
      end
    end

    context 'when API key is not present' do
      it 'initialises with username and password' do
        config[:elasticsearch][:api_key] = nil

        result = subject.connection_config(config[:elasticsearch], '0.0.0-foo')

        expect(result[:api_key]).to be_nil

        expect(result[:user]).to eq('user')
        expect(result[:password]).to eq('pw')

        expect(result[:transport_options][:headers][:'user-agent']).to eq('elastic-web-crawler-0.0.0-foo')
      end
    end

    context 'when API key is present' do
      it 'overrides username and password' do
        result = subject.connection_config(config[:elasticsearch], '0.0.0-bar')

        expect(result[:host]).to eq('notreallyaserver')
        expect(result[:port]).to eq('9200')
        expect(result[:api_key]).to eq('key')

        expect(result[:username]).to be_nil
        expect(result[:password]).to be_nil

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

  describe '#execute_with_retry' do
    let(:description) { 'Test Operation' }
    let(:block_result) { { success: true } }
    let(:block_spy) { spy('block') }
    let(:error_class) { Class.new(StandardError) }

    before do
      allow(block_spy).to receive(:call).and_return(block_result)
    end

    def execute_retry(&block)
      subject.send(:execute_with_retry, description:, &block)
    end

    context 'with default settings (3 retries, 2s delay)' do
      let(:config) { { elasticsearch: { host:, port: } } } # Use default retry config

      it 'succeeds on the first try without sleeping or logging warnings' do
        expect(subject).not_to receive(:sleep)
        expect(system_logger).not_to receive(:warn)
        expect(system_logger).not_to receive(:error)

        result = execute_retry { block_spy.call }

        expect(result).to eq(block_result)
        expect(block_spy).to have_received(:call).once
      end
    end

    context 'when success requires retries' do
      let(:config) { { elasticsearch: { host:, port:, retry_on_failure: 2, delay_on_retry: 1 } } }
      let(:attempts) { instance_double(Proc) }
      let(:attempt_counter) { double(count: 0) }

      before do
        allow(attempt_counter).to receive(:count).and_return(0, 1, 2) # Simulate 3 calls total
        allow(block_spy).to receive(:call) do
          count = attempt_counter.count
          raise error_class, "Failed attempt #{count + 1}" if count < 2

          block_result # Success on the 3rd attempt (index 2)
        end
      end

      it 'succeeds after retrying, sleeps with exponential backoff, and logs warnings' do
        expect(system_logger).to receive(:warn).with(
          %r{#{description} attempt 1/3 failed: 'Failed attempt 1'. Retrying in 1.0s..}
        ).ordered
        expect(subject).to receive(:sleep).with(1.0**1).ordered
        expect(system_logger).to receive(:warn).with(
          %r{#{description} attempt 2/3 failed: 'Failed attempt 2'. Retrying in 1.0s..}
        ).ordered
        expect(subject).to receive(:sleep).with(1.0**2).ordered
        expect(system_logger).not_to receive(:error)

        result = execute_retry { block_spy.call }

        expect(result).to eq(block_result)
        expect(block_spy).to have_received(:call).exactly(3).times
      end
    end

    context 'when all retries fail' do
      let(:config) { { elasticsearch: { host:, port:, retry_on_failure: 2, delay_on_retry: 1 } } }

      before do
        allow(block_spy).to receive(:call).and_raise(error_class, 'Persistent failure')
      end

      it 'raises the original error after exhausting retries, sleeps, logs warnings and final error' do
        expect(system_logger).to receive(:warn).with(
          %r{#{description} attempt 1/3 failed: 'Persistent failure'. Retrying in 1.0s..}
        ).ordered
        expect(subject).to receive(:sleep).with(1.0**1).ordered
        expect(system_logger).to receive(:warn).with(
          %r{#{description} attempt 2/3 failed: 'Persistent failure'. Retrying in 1.0s..}
        ).ordered
        expect(subject).to receive(:sleep).with(1.0**2).ordered
        expect(system_logger).to receive(:error).with(
          /#{description} failed after 3 attempts: 'Persistent failure'/
        ).ordered

        expect do
          execute_retry { block_spy.call }
        end.to raise_error(error_class, 'Persistent failure')

        expect(block_spy).to have_received(:call).exactly(3).times
      end
    end

    context 'when retries are disabled' do
      let(:config) { { elasticsearch: { host:, port:, retry_on_failure: false } } }

      before do
        allow(block_spy).to receive(:call).and_raise(error_class, 'Immediate failure')
      end

      it 'fails immediately, logs specific error, and does not sleep or log warnings' do
        expect(subject).not_to receive(:sleep)
        expect(system_logger).not_to receive(:warn)
        expect(system_logger).to receive(:error).with(
          /#{description} failed: 'Immediate failure'. Retries disabled./
        )

        expect do
          execute_retry { block_spy.call }
        end.to raise_error(error_class, 'Immediate failure')

        expect(block_spy).to have_received(:call).once
      end
    end
  end

  describe '#bulk' do
    let(:config) { { elasticsearch: { host:, port:, retry_on_failure: 1, delay_on_retry: 1 } } }
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

      it 'sends bulk request' do
        result = subject.bulk(payload)
        expect(result.status).to eq(200)
      end
    end

    context 'when the underlying client call fails' do
      let(:error) { Elastic::Transport::Transport::ServerError.new('[500] {"error":"boom"}') }
      let(:file_double) { double('File', puts: nil, close: nil) }

      before do
        allow(subject.transport).to receive(:perform_request).and_return(
          double(status: 200, body: '{"version":{"number":"8.13.0"}}', headers: elastic_product_headers)
        )

        allow(subject.transport).to receive(:perform_request).with('POST', '_bulk', any_args).and_raise(error)

        allow(File).to receive(:open).with(%r{output/failed_payloads/crawl-id/\d{14}}, 'w').and_yield(file_double)
      end

      it 'saves the payload after persistent errors' do
        expect(subject).to receive(:execute_with_retry).with(description: 'Bulk index').and_call_original

        expect { subject.bulk(payload) }.to raise_error(error)

        expect(file_double).to have_received(:puts).with(payload[:body].first)
        expect(file_double).to have_received(:puts).with(payload[:body].second)
      end
    end
  end

  describe '#paginated_search' do
    let(:size) { Crawler::OutputSink::Elasticsearch::SEARCH_PAGINATION_SIZE }
    let(:config) { { elasticsearch: { host:, port:, retry_on_failure: 1, delay_on_retry: 1 } } }
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
      { hits: { hits: [hit1, hit2] } }.deep_stringify_keys
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

    context 'when the underlying search call fails' do
      let(:error) { Elastic::Transport::Transport::ServerError.new('[503] {"error":"unavailable"}') }

      before do
        allow(subject).to receive(:search).and_raise(error)
      end

      it 'calls execute_with_retry and raises the error' do
        expect(subject).to receive(:execute_with_retry).with(description: 'Search').and_call_original

        expect { subject.paginated_search(index_name, query) }.to raise_error(error)
      end
    end
  end

  describe '#delete_by_query' do
    let(:config) { { elasticsearch: { host:, port:, retry_on_failure: 1, delay_on_retry: 1 } } }
    let(:delete_url) { %r{#{host}:#{port}/#{index_name}/_delete_by_query} }
    let(:query) { { query: { match_all: {} } } }

    let(:error_response) do
      { status: 500, body: '{"error":"delete_failed"}', headers: { 'Content-Type' => 'application/json' } }
    end

    let(:success_response) do
      { status: 200, body: '{"deleted": 10}',
        headers: elastic_product_headers.merge('Content-Type' => 'application/json') }
    end

    context 'when successful' do
      before do
        stub_request(:post, delete_url).to_return(success_response)
      end

      it 'calls execute_with_retry and performs the delete' do
        expect(subject).to receive(:execute_with_retry).with(description: 'Delete by query').and_call_original
        expect { subject.delete_by_query(index: index_name, body: query) }.not_to raise_error
      end
    end

    context 'when the underlying delete call fails' do
      let(:error) { Elastic::Transport::Transport::ServerError.new('[500] {"error":"delete_failed"}') }

      before do
        allow(subject.transport).to receive(:perform_request).with(
          'POST', "#{index_name}/_delete_by_query", { refresh: true }, query, anything
        ).and_raise(error)
      end

      it 'calls execute_with_retry and raises the error' do
        expect(subject).to receive(:execute_with_retry).with(description: 'Delete by query').and_call_original

        expect { subject.delete_by_query(index: index_name, body: query) }.to raise_error(error)
      end
    end
  end
end
