#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

RSpec.describe Crawler::UrlValidator do
  let(:valid_url) { 'http://example.com' }
  let(:invalid_url) { 'invalid_url' }
  let(:crawl_config) { double('CrawlConfig', domain_allowlist: ['example.com']) }
  let(:validator) { described_class.new(url: valid_url, crawl_config: crawl_config) }

  describe '#initialize' do
    context 'when crawl_config has no domain_allowlist' do
      let(:crawl_config) { double('CrawlConfig', domain_allowlist: []) }

      it 'raises an InvalidCrawlConfigError' do
        expect { described_class.new(url: valid_url, crawl_config: crawl_config) }.to raise_error(Crawler::UrlValidator::InvalidCrawlConfigError)
      end
    end

    context 'when valid parameters are provided' do
      it 'initializes with the correct attributes' do
        expect(validator.raw_url).to eq(valid_url)
        expect(validator.checks).to include(:url)
        expect(validator.results).to be_empty
      end
    end
  end

  describe '#valid_checks' do
    it 'returns the domain level checks' do
      expect(validator.valid_checks).to eq(Crawler::UrlValidator::DOMAIN_LEVEL_CHECKS)
    end
  end

  describe '#valid?' do
    context 'when all checks pass' do
      before do
        allow(validator).to receive(:validate).and_return(true)
        allow(validator).to receive(:any_failed_results?).and_return(false)
      end

      it 'returns true' do
        expect(validator.valid?).to be true
      end
    end

    context 'when any check fails' do
      before do
        allow(validator).to receive(:validate).and_return(true)
        allow(validator).to receive(:any_failed_results?).and_return(true)
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end
    end
  end

  describe '#validate' do
    it 'performs all checks and populates the results array' do
      allow(validator).to receive(:perform_check) do |check_name|
        validator.results << double('Result', failure?: false)
      end
      validator.validate
      expect(validator.results).not_to be_empty
    end
  end

  describe '#url' do
    it 'parses the raw_url' do
      expect(::Crawler::Data::URL).to receive(:parse).with(valid_url)
      validator.url
    end
  end

  describe '#normalized_url' do
    context 'when the URL is valid' do
      it 'returns the normalized URL' do
        parsed_url = double('URL', normalized_url: 'http://example.com/')
        allow(validator).to receive(:url).and_return(parsed_url)
        expect(validator.normalized_url).to eq('http://example.com/')
      end
    end

    context 'when the URL is invalid' do
      it 'returns the raw_url' do
        allow(validator).to receive(:url).and_raise(Addressable::URI::InvalidURIError)
        expect(validator.normalized_url).to eq(valid_url)
      end
    end
  end

  describe '#failed_checks' do
    it 'returns the failed checks' do
      failed_result = double('Result', failure?: true)
      allow(validator).to receive(:results).and_return([failed_result])
      expect(validator.failed_checks).to include(failed_result)
    end
  end

  describe '#validation_ok' do
    it 'adds a successful result to the results array' do
      validator.send(:validation_ok, 'test_check', 'All good')
      expect(validator.results.last.result).to eq(:ok)
      expect(validator.results.last.comment).to eq('All good')
    end
  end

  describe '#validation_warn' do
    it 'adds a warning result to the results array' do
      validator.send(:validation_warn, 'test_check', 'Something might be wrong')
      expect(validator.results.last.result).to eq(:warning)
      expect(validator.results.last.comment).to eq('Something might be wrong')
    end
  end

  describe '#validation_fail' do
    it 'adds a failure result to the results array' do
      validator.send(:validation_fail, 'test_check', 'Something went wrong')
      expect(validator.results.last.result).to eq(:failure)
      expect(validator.results.last.comment).to eq('Something went wrong')
    end
  end

  describe '#perform_check' do
    before do
      # Define a temporary method for testing
      Crawler::UrlValidator.class_eval do
        private

        def validate_test_check
          validation_ok('test_check', 'Test check passed')
        end
      end
    end

    after do
      # Remove the temporary method after testing
      Crawler::UrlValidator.send(:remove_method, :validate_test_check)
    end

    context 'when the check method exists' do
      it 'calls the check method' do
        expect(validator).to receive(:validate_test_check).and_call_original
        validator.send(:perform_check, 'test_check')
      end
    end

    context 'when the check method does not exist' do
      it 'raises an ArgumentError' do
        expect { validator.send(:perform_check, 'non_existent_check') }.to raise_error(ArgumentError, 'Invalid check name: "non_existent_check"')
      end
    end
  end

end