#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency(File.join(__dir__, '..', '..', '..', 'constants'))

java_import org.jsoup.Jsoup
java_import org.jsoup.nodes.TextNode

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

        SELECTOR_TYPE_CSS = 'css'
        SELECTOR_TYPE_XPATH = 'xpath'
        SELECTOR_TYPE_REGEXP = 'regexp'

        attr_reader :action, :field_name, :selector, :join_as, :source, :value, :type

        def initialize(rule)
          @action = rule[:action]
          @field_name = rule[:field_name]
          @selector = rule[:selector]
          @join_as = rule[:join_as]
          @source = rule[:source]
          @value = rule[:value]
          @type = nil
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

        def validate_css(sample)
          css_error = nil
          begin
            sample.css(@selector)
          rescue Nokogiri::CSS::SyntaxError, Nokogiri::XML::XPath::SyntaxError => e
            css_error = "CSS Selector is not valid: #{e.message}"
          end
          css_error
        end

        def validate_xpath(sample)
          xpath_error = nil
          begin
            sample.xpath(@selector)
          rescue Nokogiri::XML::XPath::SyntaxError, Nokogiri::CSS::SyntaxError => e
            xpath_error = "XPath Selector is not valid: #{e.message}"
          end
          xpath_error
        end

        def validate_selector
          raise ArgumentError, "Extraction rule selector can't be blank" if @selector.blank?

          if @source == SOURCES_HTML
            # For HTML we need to infer the selector type (xpath or css) based on the provided selector value,
            # because jsoup has different parsing methods for each case.
            css_error = validate_css_selector
            return if css_error.nil?

            xpath_error = validate_xpath_selector
            return if xpath_error.nil?

            # Only raise if neither were valid
            raise ArgumentError, "#{css_error}; #{xpath_error}"
          else
            begin
              Regexp.new(@selector)
              # At this point in time, URL selectors are always of type 'regexp'
              @type = SELECTOR_TYPE_REGEXP
            rescue RegexpError => e
              raise ArgumentError,
                    "Extraction rule selector `#{@selector}` is not a valid regular expression: #{e.message}"
            end
          end
        end

        def validate_css_selector
          # If valid CSS selector, @type will be set to 'css', otherwise we return the error

          Jsoup.parseBodyFragment('<a></a>').select(@selector)
          @type = SELECTOR_TYPE_CSS
          nil
        rescue Java::OrgJsoupSelect::Selector::SelectorParseException => e
          "Extraction rule selector `#{@selector}` is not a valid CSS selector: #{e.message}"
        end

        def validate_xpath_selector
          # If valid XPath selector, @type will be set to 'xpath', otherwise we return the error

          Jsoup.parseBodyFragment('<a></a>').selectXpath(@selector, TextNode.java_class)
          @type = SELECTOR_TYPE_XPATH
          nil
        rescue Java::OrgJsoupSelect::Selector::SelectorParseException => e
          "Extraction rule selector `#{@selector}` is not a valid XPath selector: #{e.message}"
        end
      end
    end
  end
end
