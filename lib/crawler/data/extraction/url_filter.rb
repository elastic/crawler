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
        REGEX_TIMEOUT ||= 0.5 # seconds
        TYPES ||= %w[begins ends contains regex].freeze

        attr_reader :type, :pattern

        def initialize(url_filter)
          @type = url_filter[:type]
          @pattern = url_filter[:pattern]
          validate_url_filter
        end

        private

        def validate_url_filter
          unless TYPES.include?(@type)
            raise ArgumentError, "Extraction ruleset url_filter type must be one of #{TYPES.join(', ')}"
          end

          raise ArgumentError, 'URL pattern can not be blank' if @pattern.blank?

          case @type
          when 'begins'
            raise ArgumentError, 'pattern must begin with a slash (/)' unless @pattern.start_with?('/')
          when 'regex'
            begin
              _ = Regexp.new(@pattern)
            rescue RegexpError => e
              raise ArgumentError, "regular expression is invalid: #{e.message}"
            end
          end
        end

        def url_match?(url)
          Timeout.timeout(REGEX_TIMEOUT) do
            @url_pattern.match?(url.to_s)
          end
        end
      end
    end
  end
end
