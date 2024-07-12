#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::Extraction::UrlFilter) do
  let(:type) { 'begins' }
  let(:pattern) { '/foo' }

  let(:filter_input) { { type:, pattern: } }

  describe '#initialize' do
    it 'initializes with a valid url filter' do
      url_filter = described_class.new(filter_input)

      expect(url_filter.type).to eq(type)
      expect(url_filter.pattern).to eq(pattern)
    end

    context 'when type is invalid' do
      let(:valid_types) { Crawler::Data::Extraction::UrlFilter::TYPES.join(', ') }
      let(:type) { 'invalid' }

      it 'raises an error' do
        expect do
          described_class.new(filter_input)
        end.to raise_error(
          ArgumentError,
          "Extraction ruleset url_filter `#{type}` is invalid; value must be one of #{valid_types}"
        )
      end
    end

    context 'when pattern is blank' do
      let(:pattern) { '' }

      it 'raises an error' do
        expect do
          described_class.new(filter_input)
        end.to raise_error(
          ArgumentError,
          'Extraction ruleset url_filter pattern can not be blank'
        )
      end
    end

    context 'when type is `begins` and pattern is invalid' do
      let(:pattern) { 'invalid/pattern' }

      it 'raises an error' do
        expect do
          described_class.new(filter_input)
        end.to raise_error(
          ArgumentError,
          'Extraction ruleset url_filter pattern must begin with a slash (/) if type is `begins`'
        )
      end
    end

    context 'when type is `regex` and pattern is invalid' do
      let(:type) { 'regex' } # broken regex
      let(:pattern) { '[a-z' } # broken regex

      it 'raises an error' do
        expect do
          described_class.new(filter_input)
        end.to raise_error(
          ArgumentError,
          /^Extraction ruleset url_filter pattern regex is invalid: /
        )
      end
    end
  end
end
