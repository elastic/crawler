#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::Extraction::Rule) do
  let(:action) { 'extract' }
  let(:field_name) { 'foo' }
  let(:selector) { '.foo' }
  let(:join_as) { 'array' }
  let(:source) { 'html' }

  let(:rule_input) { { action:, field_name:, selector:, join_as:, source: } }

  describe '#initialize' do
    it 'initializes with a valid rule' do
      rule = described_class.new(rule_input)

      expect(rule.action).to eq(action)
      expect(rule.field_name).to eq(field_name)
      expect(rule.selector).to eq(selector)
      expect(rule.join_as).to eq(join_as)
      expect(rule.source).to eq(source)
    end

    context 'when action is invalid' do
      let(:action) { 'invalid' }
      let(:expected_actions) { Crawler::Data::Extraction::Rule::ACTIONS.join(', ') }
      it 'raises an error' do
        expect do
          described_class.new(rule_input)
        end.to raise_error(
          ArgumentError,
          "Extraction rule action `#{action}` is invalid; value must be one of #{expected_actions}"
        )
      end
    end

    context 'when action is `set`' do
      let(:action) { 'set' }

      before :each do
        rule_input[:value] = value
      end

      [0, 1, '', 'foo', [], %w[an array], { an: 'object?' }, true, false].each do |valid_value|
        let(:value) { valid_value }

        it 'assigns a value' do
          rule = described_class.new(rule_input)
          expect(rule.action).to eq('set')
          expect(rule.value).to eq(value)
        end
      end
    end

    context 'when action is `set` and value is nil' do
      let(:action) { 'set' }
      let(:value) { nil }

      it 'raises an error' do
        expect do
          described_class.new(rule_input)
        end.to raise_error(
          ArgumentError,
          "Extraction rule value can't be blank when action is `set`"
        )
      end
    end

    context 'when field_name is not a string' do
      [nil, 0, 1, [], %w[an array], { an: 'object?' }, true, false].each do |invalid_field_name|
        let(:field_name) { invalid_field_name }

        it 'raises an error' do
          expect do
            described_class.new(rule_input)
          end.to raise_error(
            ArgumentError,
            'Extraction rule field_name must be a string'
          )
        end
      end
    end

    context 'when field_name is empty' do
      let(:field_name) { '' }

      it 'raises an error' do
        expect do
          described_class.new(rule_input)
        end.to raise_error(
          ArgumentError,
          "Extraction rule field_name can't be blank"
        )
      end
    end

    context 'when field_name is reserved' do
      let(:reserved_field_names) { Constants::RESERVED_FIELD_NAMES }

      # can't use the above variable for this as it's used in the context block
      Constants::RESERVED_FIELD_NAMES.each do |reserved_field_name|
        let(:field_name) { reserved_field_name }

        it 'raises an error' do
          expect do
            described_class.new(rule_input)
          end.to raise_error(
            ArgumentError,
            "Extraction rule field_name can't be a reserved field: #{reserved_field_names.join(', ')}"
          )
        end
      end
    end

    context 'when join_as is invalid' do
      let(:valid_joins) { Crawler::Data::Extraction::Rule::JOINS.join(', ') }
      let(:join_as) { 'concatenate?' } # invalid

      it 'raises an error' do
        expect do
          described_class.new(rule_input)
        end.to raise_error(
          ArgumentError,
          "Extraction rule join_as `#{join_as}` is invalid; value must be one of #{valid_joins}"
        )
      end
    end

    context 'when source is invalid' do
      let(:valid_sources) { Crawler::Data::Extraction::Rule::SOURCES.join(', ') }
      let(:source) { 'xml' } # invalid

      it 'raises an error' do
        expect do
          described_class.new(rule_input)
        end.to raise_error(
          ArgumentError,
          "Extraction rule source `#{source}` is invalid; value must be one of #{valid_sources}"
        )
      end
    end

    context 'when selector is invalid' do
      let(:selector) { '.#class-or-id' }

      it 'raises an error' do
        expect do
          described_class.new(rule_input)
        end.to raise_error(
          ArgumentError,
          /^Extraction rule selector `\.#class-or-id` is not valid: */
        )
      end
    end
  end
end
