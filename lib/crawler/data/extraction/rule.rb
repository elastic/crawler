#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Data
    module Extraction
      class Rule
        ACTION_TYPE_EXTRACT = 'extract'
        ACTION_TYPE_SET = 'set'
        ACTIONS = [ACTION_TYPE_EXTRACT, ACTION_TYPE_SET].freeze
        JOINS = %w[array string].freeze
        SOURCES = %w[url html].freeze
        RESERVED_FIELD_NAMES = %w[body_content domains headings meta_description title url url_host url_path
                                  url_path_dir1 url_path_dir2 url_path_dir3 url_port url_scheme].freeze

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

          return unless RESERVED_FIELD_NAMES.include?(@field_name)

          raise ArgumentError,
                "Extraction rule field_name can't be a reserved field: #{RESERVED_FIELD_NAMES.join(', ')}"
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

          # NOTE: expand for other sources when added (e.g. url)
          begin
            Nokogiri::HTML::DocumentFragment.parse('<a></a>').search(@selector)
          rescue Nokogiri::CSS::SyntaxError, Nokogiri::XML::XPath::SyntaxError => e
            raise ArgumentError, "Extraction rule selector `#{@selector}` is not valid: #{e.message}"
          end
        end
      end
    end
  end
end
