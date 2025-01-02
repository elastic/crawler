#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::UrlValidator) do
  let(:valid_url) { Crawler::Data::URL.parse('http://example.com') }
  let(:domain_allowlist) { ['example.com'] }
  let(:crawl_config) { double('CrawlConfig', domain_allowlist:) }
  let(:validator) { described_class.new(url: valid_url, crawl_config:) }
  let(:host) { domain_allowlist[0] }
  let(:port) { 80 }
  let(:details) { { host:, port: } }
  let(:url) { instance_double('Crawler::Data::URL', host:, inferred_port: port) }

  describe '#validate_tcp' do
    before do
      validator.singleton_class.include(Crawler::UrlValidator::TcpCheckConcern)
      allow(validator).to receive(:proxy_configured?).and_return(proxy_configured)
      allow(validator).to receive(:url).and_return(url)
      allow(validator).to receive(:validation_ok)
      allow(validator).to receive(:validation_warn)
      allow(validator).to receive(:validation_fail)
    end

    context 'when proxy is configured' do
      let(:proxy_configured) { true }

      it 'calls validation_warn with the correct parameters' do
        validator.validate_tcp
        expect(validator)
          .to have_received(:validation_warn)
          .with(:tcp, 'TCP connection check could not be performed via an HTTP proxy.')
      end
    end

    context 'when proxy is not configured' do
      let(:proxy_configured) { false }

      context 'when TCP connection is successful' do
        before do
          allow(Socket)
            .to receive(:tcp)
            .with(host, port, connect_timeout: Crawler::UrlValidator::TCP_CHECK_TIMEOUT).and_yield
        end

        it 'calls validation_ok with the correct parameters' do
          validator.validate_tcp
          expect(validator)
            .to have_received(:validation_ok)
            .with(:tcp, 'TCP connection successful', details)
        end
      end

      context 'when TCP connection times out' do
        before do
          allow(Socket)
            .to receive(:tcp)
            .with(host, port, connect_timeout: Crawler::UrlValidator::TCP_CHECK_TIMEOUT).and_raise(Errno::ETIMEDOUT)
        end

        it 'calls validation_fail with the correct parameters' do
          validator.validate_tcp
          expect(validator)
            .to have_received(:validation_fail)
            .with(:tcp, /TCP connection to #{host}:#{port} timed out/, details)
        end
      end

      context 'when TCP connection fails with a SocketError' do
        before do
          allow(Socket)
            .to receive(:tcp)
            .with(host, port, connect_timeout: Crawler::UrlValidator::TCP_CHECK_TIMEOUT)
            .and_raise(SocketError, 'socket error')
        end

        it 'calls validation_fail with the correct parameters' do
          validator.validate_tcp
          expect(validator)
            .to have_received(:validation_fail)
            .with(:tcp, /TCP connection to #{host}:#{port} failed: socket error/, details)
        end
      end

      context 'when TCP connection fails with a SystemCallError' do
        before do
          allow(Socket)
            .to receive(:tcp)
            .with(host, port, connect_timeout: Crawler::UrlValidator::TCP_CHECK_TIMEOUT)
            .and_raise(SystemCallError, 'system call error')
        end

        it 'calls validation_fail with the correct parameters' do
          validator.validate_tcp
          expect(validator)
            .to have_received(:validation_fail)
            .with(:tcp, /TCP connection to #{host}:#{port} failed:/, details)
        end
      end
    end
  end
end
