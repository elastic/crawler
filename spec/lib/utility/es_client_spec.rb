# frozen_string_literal: true

require 'elasticsearch'

RSpec.describe(Utility::EsClient) do
  let(:system_logger) { double }
  let(:host) { 'http://notreallyaserver' }
  let(:config) do
    {
      elasticsearch: {
        username: 'user',
        password: 'pw',
        api_key: 'key',
        host: host
      }
    }.deep_symbolize_keys
  end

  let(:subject) { described_class.new(config[:elasticsearch], system_logger, '0.0.0-test') }

  before(:each) do
    stub_request(:get, "#{host}:9200/")
      .to_return(status: 403, body: '', headers: {})
    stub_request(:get, "#{host}:9200/_cluster/health")

    # TODO: make a factory or something for system_logger mocks
    allow(system_logger).to receive(:info)
    allow(system_logger).to receive(:debug)
  end

  xcontext 'when Elasticsearch::Client arguments are presented' do
    before(:example) do
      # TODO: implement when we support TLS options
      remove api_key to force Elasticsearch::Client pickup TLS options
      config[:elasticsearch].delete(:api_key)
    end

    context 'when transport_options is presented' do
      # TODO: implement when we support transport options
      let(:transport_options) { { ssl: { verify: false } } }

      it 'configures Elasticsearch client with transport_options' do
        config[:elasticsearch][:transport_options] = transport_options
        expect(subject.transport.options[:transport_options][:ssl]).to eq(transport_options[:ssl])
      end
    end

    context 'when ca_fingerprint is presented' do
      # TODO: implement when we support transport ca_fingerprint
      let(:ca_fingerprint) { '64F2593F...' }

      it 'configures Elasticsearch client with ca_fingerprint' do
        config[:elasticsearch][:ca_fingerprint] = ca_fingerprint
        # there is no other way to get ca_fingerprint variable
        expect(subject.instance_variable_get(:@transport).instance_variable_get(:@ca_fingerprint)).to eq(ca_fingerprint)
      end
    end
  end

  describe '#connection_configs' do
    context 'when API key is not present' do
      it 'initialises with username and password' do
        config[:elasticsearch][:api_key] = nil

        result = subject.connection_configs(config[:elasticsearch], '0.0.0-foo')

        expect(result[:url]).to eq('http://user:pw@notreallyaserver')
        expect(result[:host]).to be_nil
        expect(result[:api_key]).to be_nil
        expect(result[:transport_options][:headers][:'user-agent']).to eq('elastic-web-crawler-0.0.0-foo')
      end
    end

    context 'when API key is present' do
      it 'overrides username and password' do
        result = subject.connection_configs(config[:elasticsearch], '0.0.0-bar')

        expect(result[:url]).to be_nil
        expect(result[:host]).to eq(host)
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

        result = subject.connection_configs(config[:elasticsearch], '0.0.0-test')

        expect(result['headers']).to eq(headers)
      end
    end

    context 'when headers are not present' do
      it 'configures Elasticsearch client with no headers' do
        config[:elasticsearch][:headers] = nil

        result = subject.connection_configs(config[:elasticsearch], '0.0.0-test')

        expect(result).to_not have_key(:headers)
      end
    end
  end
end
