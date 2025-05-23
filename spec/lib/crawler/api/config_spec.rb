#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'yaml'

RSpec.describe(Crawler::API::Config) do
  describe '#initialize' do
    let(:domain1) do
      {
        url: 'https://domain1.com',
        seed_urls: %w[https://domain1.com/forum https://domain1.com/wiki],
        sitemap_urls: %w[https://domain1.com/sitemap/foo.xml]
      }
    end
    let(:domain2) { { url: 'http://domain2.com' } }
    let(:domains) { [domain1, domain2] }

    let(:expected_allowlist) { %W[#{domain1[:url]}:443 #{domain2[:url]}:80] }
    let(:expected_seed_urls) { ["#{domain2[:url]}/"] + domain1[:seed_urls] }

    let(:output_dir) { '/tmp/crawler/example.com/123' }

    it 'should fail when provided with unknown options' do
      expect do
        Crawler::API::Config.new(fubar: 42)
      end.to raise_error(ArgumentError, /Unexpected configuration options.*fubar/)
    end

    it 'can define a crawl with console output' do
      config = Crawler::API::Config.new(
        domains:,
        output_sink: :console
      )

      expect(config.domain_allowlist.map(&:to_s)).to match_array(expected_allowlist)
      expect(config.seed_urls.map(&:to_s).to_a).to match_array(expected_seed_urls)
      expect(config.output_sink).to eq(:console)
      expect(config.output_dir).to eq('./crawled_docs')
    end

    it 'can define a crawl with file output' do
      config = Crawler::API::Config.new(
        domains:,
        output_sink: :file,
        output_dir:
      )

      expect(config.domain_allowlist.map(&:to_s)).to match_array(expected_allowlist)
      expect(config.seed_urls.map(&:to_s).to_a).to match_array(expected_seed_urls)
      expect(config.output_sink).to eq(:file)
      expect(config.output_dir).to eq(output_dir)
    end

    it 'should use the console sink by default' do
      config = Crawler::API::Config.new(
        domains:
      )

      expect(config.domain_allowlist.map(&:to_s)).to match_array(expected_allowlist)
      expect(config.seed_urls.map(&:to_s).to_a).to match_array(expected_seed_urls)
      expect(config.output_sink).to eq(:elasticsearch)
      expect(config.output_dir).to eq('./crawled_docs')
    end

    context 'when a domain is missing a main URL' do
      let(:domain2) { { foo: 'bar' } }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Each domain requires a url')
      end
    end

    context 'when a domain URL is invalid' do
      let(:domain2) { { url: 'huh?' } }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Domain "huh?" does not have a URL scheme')
      end
    end

    context 'when a domain URL has a path' do
      let(:domain2) { { url: 'http://domain2.com/baa' } }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Domain "http://domain2.com/baa" cannot have a path')
      end
    end

    context 'when a domain URL is not an HTTP(S) site' do
      let(:domain2) { { url: 'file://location/to/file.txt' } }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Domain "file://location/to/file.txt" is not an HTTP(S) site')
      end
    end

    context 'when domains is empty' do
      let(:domains) { [] }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Needs at least one domain')
      end
    end

    context 'when sink lock configuration is provided' do
      let(:config_with_sink_lock) do
        {
          domains: [{ url: 'http://example.com' }],
          sink_lock_retry_interval: 10,
          sink_lock_max_retries: 50
        }
      end

      it 'should load the provided sink lock values' do
        config = Crawler::API::Config.new(config_with_sink_lock)
        expect(config.sink_lock_retry_interval).to eq(10)
        expect(config.sink_lock_max_retries).to eq(50)
      end
    end

    context 'when crawl rules exist' do
      let(:domain2) do
        {
          url: 'http://domain2.com',
          crawl_rules: [
            { policy: 'deny', pattern: '/blog', type: 'begins' }
          ]
        }
      end

      it 'should create a crawl rule for the domain' do
        config = Crawler::API::Config.new(domains:)

        crawl_rules_d1 = config.crawl_rules['http://domain1.com']
        expect(crawl_rules_d1).to be_nil

        crawl_rules_d2 = config.crawl_rules['http://domain2.com']
        expect(crawl_rules_d2.size).to eq(1)
        expect(crawl_rules_d2.first.policy).to eq(:deny)
      end
    end

    context 'when crawl rules is not an array' do
      let(:domain2) do
        {
          url: 'http://domain2.com',
          crawl_rules: { policy: 'deny', pattern: '/blog', type: 'begins' }
        }
      end

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Crawl rules for http://domain2.com is not an array')
      end
    end
    context 'when configuring SSL CA certificates' do
      def expect_x509_certificates(certs)
        expect(certs).to all(be_a(Java::JavaSecurityCert::X509Certificate))
      end

      let(:base_params) { { domains: [{ url: 'https://example.com' }] } }

      let(:valid_ca_cert_path) { 'spec/fixtures/ssl/ca.crt' }
      let(:invalid_ca_cert_path) { 'spec/fixtures/ssl/invalid.crt' }

      let(:expired_cert_path) { 'spec/fixtures/ssl/expired/example.crt' }
      let(:self_signed_cert_path) { 'spec/fixtures/ssl/self-signed/example.crt' }

      let(:non_existent_cert_path) { '/path/to/non_existent/cert.pem' }
      let(:unreadable_cert_path) { 'spec/fixtures/ssl/unreadable.crt' }

      let(:valid_ca_cert_content) { File.read(valid_ca_cert_path) }
      let(:invalid_ca_cert_content) { File.read(invalid_ca_cert_path) }

      let(:yaml_config_path) { 'spec/fixtures/ssl/config_with_cert.yml' }

      it 'defaults to an empty array when no certificates are provided' do
        config = Crawler::API::Config.new(base_params)
        expect(config.ssl_ca_certificates).to eq([])
      end

      it 'accepts an explicitly provided empty array' do
        config = Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: []))
        expect(config.ssl_ca_certificates).to eq([])
      end

      it 'raises ArgumentError if ssl_ca_certificates option is not an array' do
        expect do
          Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: 'not-an-array'))
        end.to raise_error(ArgumentError, 'ssl_ca_certificates must be a list of certificates or paths to certificates')
      end

      it 'raises ArgumentError if an element within the array is not a string' do
        expect do
          Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: [123]))
        end.to raise_error(
          ArgumentError,
          'each entry of ssl_ca_certificates must be a certificate or a path to a certificate'
        )
      end

      context 'with certificate content strings' do
        it 'parses a valid certificate string' do
          config = Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: [valid_ca_cert_content]))
          expect(config.ssl_ca_certificates.size).to eq(1)
          expect_x509_certificates(config.ssl_ca_certificates)
        end

        it 'raises ArgumentError for an invalid certificate string' do
          expect do
            Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: [invalid_ca_cert_content]))
          end.to raise_error(ArgumentError, /Error while parsing an SSL certificate/)
        end
      end

      context 'with certificate file paths' do
        it 'loads a certificate from a valid file path' do
          config = Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: [valid_ca_cert_path]))
          expect(config.ssl_ca_certificates.size).to eq(1)
          expect_x509_certificates(config.ssl_ca_certificates)
        end

        it 'loads a certificate from an expired certificate file path' do
          config = Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: [expired_cert_path]))
          expect(config.ssl_ca_certificates.size).to eq(1)
          expect_x509_certificates(config.ssl_ca_certificates)
        end

        it 'loads a certificate from a self-signed certificate file path' do
          config = Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: [self_signed_cert_path]))
          expect(config.ssl_ca_certificates.size).to eq(1)
          expect_x509_certificates(config.ssl_ca_certificates)
        end

        it 'raises ArgumentError if the file does not exist' do
          expect do
            Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: [non_existent_cert_path]))
          end.to raise_error(ArgumentError, /Error while loading an SSL certificate .* No such file or directory/)
        end

        it 'raises ArgumentError if the file is unreadable' do
          allow(File).to receive(:read).with(unreadable_cert_path).and_raise(Errno::EACCES.new(unreadable_cert_path))
          expect do
            Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: [unreadable_cert_path]))
          end.to raise_error(ArgumentError, /Error while loading an SSL certificate .* Permission denied/)
        end

        it 'loads certificates from a YAML configuration file' do
          yaml_config = YAML.load_file(yaml_config_path)
          certificates_from_yaml = yaml_config['ssl_ca_certificates']
          config = Crawler::API::Config.new(base_params.merge(ssl_ca_certificates: certificates_from_yaml))

          expect(config.ssl_ca_certificates.size).to eq(3) # Expecting 3 certs from the YAML file
          expect_x509_certificates(config.ssl_ca_certificates)
        end
      end
    end
  end
end
