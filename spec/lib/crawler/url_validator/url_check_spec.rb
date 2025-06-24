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
  let(:scheme) { 'http' }
  let(:supported_scheme) { true }
  let(:path) { '' }
  let(:configuration) { true }
  let(:url) { instance_double('Crawler::Data::URL', scheme:, supported_scheme?: supported_scheme, path:) }

  describe '#validate_url' do
    before do
      # Define a temporary method for testing
      Crawler::UrlValidator.class_eval do
        private

        def configuration; end
      end

      validator.singleton_class.include(Crawler::UrlValidator::UrlCheckConcern)
      allow(validator).to receive(:url).and_return(url)
      allow(validator).to receive(:configuration)
      allow(validator).to receive(:validation_ok)
      allow(validator).to receive(:validation_fail)
    end

    after do
      # Remove the temporary method after testing
      Crawler::UrlValidator.send(:remove_method, :configuration)
    end

    context 'when URL scheme is missing' do
      let(:scheme) { '' }

      it 'calls validation_fail with the correct parameters' do
        validator.validate_url(crawl_config)
        expect(validator)
          .to have_received(:validation_fail)
          .with(:url, 'URL scheme is missing. Domain URLs must start with https:// or http://')
      end
    end

    context 'when URL scheme is unsupported' do
      let(:supported_scheme) { false }

      it 'calls validation_fail with the correct parameters' do
        validator.validate_url(crawl_config)
        expect(validator)
          .to have_received(:validation_fail)
          .with(:url, "Unsupported URL scheme: #{scheme}", scheme:)
      end
    end

    context 'when URL contains a path and configuration is not present' do
      let(:path) { '/somepath' }
      let(:configuration) { false }

      it 'calls validation_fail with the correct parameters' do
        validator.validate_url(crawl_config)
        expect(validator)
          .to have_received(:validation_fail)
          .with(:url, 'Domain URLs cannot contain a path')
      end
    end

    context 'when URL structure is valid' do
      it 'calls validation_ok with the correct parameters' do
        validator.validate_url(crawl_config)
        expect(validator)
          .to have_received(:validation_ok)
          .with(:url, 'URL structure looks valid')
      end
    end

    context 'when there is an error parsing the domain name' do
      before do
        allow(url).to receive(:scheme).and_raise(Addressable::URI::InvalidURIError, 'invalid URI')
      end

      it 'calls validation_fail with the correct parameters' do
        validator.validate_url(crawl_config)
        expect(validator)
          .to have_received(:validation_fail)
          .with(:url, 'Error parsing domain name: invalid URI')
      end
    end
  end
end
