#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

# Mock class definitions
class Crawler::RuleEngine::Elasticsearch
  def initialize(crawl_config) end

  def crawl_rules_outcome(url) end
end

RSpec.describe(Crawler::UrlValidator) do
  let(:valid_url) { Crawler::Data::URL.parse('http://example.com') }
  let(:domain_allowlist) { ['example.com'] }
  let(:crawl_config) { double('CrawlConfig', domain_allowlist: domain_allowlist) }
  let(:validator) { described_class.new(url: valid_url, crawl_config: crawl_config) }
  let(:rule_engine) { double('Crawler::RuleEngine::Elasticsearch') }
  let(:outcome) { double('Outcome', allowed?: allowed, details: { rule: rule }) }
  let(:rule) { double('Rule', source: 'some_rule_source') }

  describe '#validate_crawl_rules' do

    before do
      allow(Crawler::RuleEngine::Elasticsearch).to receive(:new).with(crawl_config).and_return(rule_engine)
      allow(rule_engine).to receive(:crawl_rules_outcome).with(validator.normalized_url).and_return(outcome)
      allow(validator).to receive(:validation_ok)
      allow(validator).to receive(:validation_fail)
    end

    context 'when the URL is allowed by a crawl rule' do
      let(:allowed) { true }

      it 'calls validation_ok with the correct parameters' do
        validator.validate_crawl_rules
        expect(validator)
          .to have_received(:validation_ok)
                .with(:crawl_rules, 'The URL is allowed by one of the crawl rules', rule: 'some_rule_source')
      end
    end

    context 'when the URL is denied by a crawl rule' do
      let(:allowed) { false }

      it 'calls validation_fail with the correct parameters' do
        validator.validate_crawl_rules
        expect(validator)
          .to have_received(:validation_fail)
                .with(:crawl_rules, 'The URL is denied by a crawl rule', rule: 'some_rule_source')
      end
    end

    context 'when the URL is denied because it did not match any rules' do
      let(:allowed) { false }
      let(:rule) { nil }

      it 'calls validation_fail with the correct parameters' do
        validator.validate_crawl_rules
        expect(validator)
          .to have_received(:validation_fail)
                .with(:crawl_rules, 'The URL is denied because it did not match any rules')
      end
    end
  end

end