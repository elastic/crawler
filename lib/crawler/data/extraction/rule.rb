#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency(File.join(__dir__, '..', '..', '..', 'constants'))

module Crawler
  module Data
    module Extraction
      class Rule
        ACTION_TYPE_EXTRACT = 'extract'
        ACTION_TYPE_SET = 'set'
        ACTIONS = [ACTION_TYPE_EXTRACT, ACTION_TYPE_SET].freeze

        JOINS_ARRAY = 'array'
        JOINS_STRING = 'string'
        JOINS = [JOINS_ARRAY, JOINS_STRING].freeze

        SOURCES_URL = 'url'
        SOURCES_HTML = 'html'
        SOURCES = [SOURCES_URL, SOURCES_HTML].freeze

        attr_reader :action, :field_name, :selector, :join_as, :source, :value

        def initialize(rule)
          @action = rule[:action]
          @field_name = rule[:field_name]
          @selector = rule[:selector]
          @join_as = rule[:join_as]
          @source = rule[:source]
          @value = rule[:value]
          validate_rule
        end

        private

        def validate_rule
          validate_actions
          validate_field_name
          validate_join_as
          validate_source
          validate_selector
        end

        def validate_actions
          unless ACTIONS.include?(@action)
            raise ArgumentError,
                  "Extraction rule action `#{@action}` is invalid; value must be one of #{ACTIONS.join(', ')}"
          end

          return unless @action == ACTION_TYPE_SET && @value.nil?

          raise ArgumentError, "Extraction rule value can't be blank when action is `#{ACTION_TYPE_SET}`"
        end

        def validate_field_name
          raise ArgumentError, 'Extraction rule field_name must be a string' unless @field_name.is_a?(String)

          raise ArgumentError, "Extraction rule field_name can't be blank" if @field_name == ''

          return unless Constants::RESERVED_FIELD_NAMES.include?(@field_name)

          raise ArgumentError,
                "Extraction rule field_name can't be a reserved field: #{Constants::RESERVED_FIELD_NAMES.join(', ')}"
        end

        def validate_join_as
          return if @action == ACTION_TYPE_SET || JOINS.include?(@join_as)

          raise ArgumentError,
                "Extraction rule join_as `#{@join_as}` is invalid; value must be one of #{JOINS.join(', ')}"
        end

        def validate_source
          return if SOURCES.include?(@source)

          raise ArgumentError,
                "Extraction rule source `#{@source}` is invalid; value must be one of #{SOURCES.join(', ')}"
        end

        def validate_selector
          raise ArgumentError, "Extraction rule selector can't be blank" if @selector.blank?

          if @source == SOURCES_HTML
            css_error = nil
            xpath_error = nil
            sample = Nokogiri::HTML::DocumentFragment.parse('<a></a>')

            begin
              sample.css(@selector)
            rescue Nokogiri::CSS::SyntaxError, Nokogiri::XML::XPath::SyntaxError => e
              # raise ArgumentError, "Extraction rule selector `#{@selector}` is not a valid HTML selector: #{e.message}"
              css_error = e.message
            end

            begin
              sample.xpath(@selector)
            rescue Nokogiri::XML::XPath::SyntaxError, Nokogiri::CSS::SyntaxError => e
              xpath_error = e.message
            end

            if xpath_error && css_error
              css_error = "CSS Selector is not valid: #{css_error}"
              xpath_error = "XPath Selector is not valid: #{xpath_error}"
            end
          else
            begin
              Regexp.new(@selector)
            rescue RegexpError => e
              raise ArgumentError,
                    "Extraction rule selector `#{@selector}` is not a valid regular expression: #{e.message}"
            end
          end
        end
      end
    end
  end
end
