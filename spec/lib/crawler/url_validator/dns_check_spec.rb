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

  describe '#validate_dns' do
    before do
      validator.singleton_class.include(Crawler::UrlValidator::DnsCheckConcern)
    end

    context 'when proxy is configured' do
      before do
        allow(validator).to receive(:proxy_configured?).and_return(true)
        allow(validator).to receive(:validation_warn)
      end

      it 'calls validation_warn with the correct parameters' do
        validator.validate_dns
        expect(validator)
          .to have_received(:validation_warn)
          .with(:dns, 'DNS resolution check could not be performed via an HTTP proxy.')
      end
    end

    context 'when proxy is not configured' do
      let(:resolv) { instance_double('Resolv') }
      let(:addresses) { [Resolv::IPv4.create('127.0.0.1')] }

      before do
        allow(validator).to receive(:proxy_configured?).and_return(false)
        allow(Resolv).to receive(:new).and_return(resolv)
        allow(resolv).to receive(:getaddresses).and_return(addresses)
        allow(validator).to receive(:validation_ok)
        allow(validator).to receive(:validation_fail)
      end

      context 'when DNS resolution is successful' do
        it 'calls validation_ok with the correct parameters' do
          validator.validate_dns
          expect(validator)
            .to have_received(:validation_ok)
            .with(:dns, 'Domain name resolution successful: 1 addresses found', addresses:)
        end
      end

      context 'when DNS resolution fails with no addresses found' do
        let(:addresses) { [] }

        it 'calls validation_fail with the correct parameters' do
          validator.validate_dns
          expect(validator)
            .to have_received(:validation_fail)
            .with(:dns, 'DNS name resolution failed. No suitable addresses found!')
        end
      end

      context 'when DNS resolution raises an error' do
        before do
          allow(resolv).to receive(:getaddresses).and_raise(Resolv::ResolvError, 'DNS error')
        end

        it 'calls validation_fail with the correct parameters' do
          validator.validate_dns
          expect(validator)
            .to have_received(:validation_fail)
            .with(:dns, /DNS resolution failure: DNS error. Please check the spelling of your domain/)
        end
      end
    end
  end
end
