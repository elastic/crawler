#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Data
    module Extraction
      class UrlFilter
        REGEX_TIMEOUT = 0.5 # seconds
        TYPES = %w[begins ends contains regex].freeze

        attr_reader :type, :pattern

        def initialize(url_filter)
          @type = url_filter[:type]
          @pattern = url_filter[:pattern]
          validate_url_filter
        end

        private

        def validate_url_filter
          unless TYPES.include?(@type)
            raise ArgumentError,
                  "Extraction ruleset url_filter `#{@type}` is invalid; value must be one of #{TYPES.join(', ')}"
          end

          raise ArgumentError, 'Extraction ruleset url_filter pattern can not be blank' if @pattern.blank?

          case @type
          when 'begins'
            unless @pattern.start_with?('/')
              raise ArgumentError,
                    'Extraction ruleset url_filter pattern must begin with a slash (/) if type is `begins`'
            end
          when 'regex' then validate_regex
          end
        end

        def validate_regex
          _ = Regexp.new(@pattern)
        rescue RegexpError => e
          raise ArgumentError, "Extraction ruleset url_filter pattern regex is invalid: #{e.message}"
        end
      end
    end
  end
end
