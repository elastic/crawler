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
  let(:url) { instance_double('Crawler::Data::URL', domain: domain_allowlist[0], domain_name: domain_allowlist[0]) }
  let(:validator) { described_class.new(url: valid_url, crawl_config:) }

  describe '#validate_domain_access' do
    before do
      validator.singleton_class.include(Crawler::UrlValidator::DomainAccessCheckConcern)
      allow(validator).to receive(:crawler_api_config).and_return(crawl_config)
      allow(validator).to receive(:url).and_return(url)
      allow(validator).to receive(:validation_ok)
      allow(validator).to receive(:validation_fail)
    end

    context 'when the URL matches one of the configured domains' do
      it 'calls validation_ok with the correct parameters' do
        validator.validate_domain_access
        expect(validator)
          .to have_received(:validation_ok)
          .with(:domain_access, 'The URL matches one of the configured domains', domain: 'example.com')
      end
    end

    context 'when the URL does not match any configured domains' do
      let(:url) { instance_double('Crawler::Data::URL', domain: 'notexample.com', domain_name: 'notexample.com') }

      it 'calls validation_fail with the correct parameters' do
        validator.validate_domain_access
        expect(validator)
          .to have_received(:validation_fail)
          .with(:domain_access, 'The URL does not match any configured domains')
      end
    end
  end
end
