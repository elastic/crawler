#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::Extraction::Ruleset) do
  let(:url_filters) do
    [
      { type: 'begins', pattern: '/blog' },
      { type: 'regex', pattern: '/blog/*' }
    ]
  end
  let(:rules) do
    [
      { action: 'extract', field_name: 'foo', selector: '.foo', join_as: 'array', source: 'html' },
      { action: 'set', field_name: 'bar', selector: '.bar', value: 'Bar exists!', source: 'html' }
    ]
  end
  let(:ruleset_input) do
    {
      rules:,
      url_filters:
    }
  end

  describe '#initialize' do
    it 'initializes with a valid ruleset' do
      ruleset = described_class.new(ruleset_input)

      expect(ruleset.rules.size).to eq(2)
      expect(ruleset.rules.map(&:action)).to match_array(%w[extract set])

      expect(ruleset.url_filters.size).to eq(2)
      expect(ruleset.url_filters.map(&:type)).to eq(%w[begins regex])
    end

    context 'when rules and url_filters are empty' do
      [[], nil].each do |empty_param|
        let(:url_filters) { empty_param }
        let(:rules) { empty_param }
        it 'initializes with empty arrays' do
          ruleset = described_class.new(ruleset_input)

          expect(ruleset.rules).to eq([])
          expect(ruleset.url_filters).to eq([])
        end
      end
    end

    context 'when rules is an invalid type' do
      ['', 'a string?', 0, 1, true, false, { foo: 'bar' }].each do |invalid_rule|
        let(:rules) { invalid_rule }
        it 'raises an ArgumentError' do
          expect do
            described_class.new(ruleset_input)
          end.to raise_error(ArgumentError, 'Extraction ruleset rules must be an array')
        end
      end
    end

    context 'when url_filters is an invalid type' do
      ['', 'a string?', 0, 1, true, false, { foo: 'bar' }].each do |invalid_filter|
        let(:url_filters) { invalid_filter }
        it 'raises an ArgumentError' do
          expect do
            described_class.new(ruleset_input)
          end.to raise_error(ArgumentError, 'Extraction ruleset url_filters must be an array')
        end
      end
    end
  end
end
