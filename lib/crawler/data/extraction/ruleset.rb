#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_relative 'rule'
require_relative 'url_filter'

module Crawler
  module Data
    module Extraction
      class Ruleset
        def initialize(ruleset)
          @ruleset = ruleset
          validate_ruleset

          # initialize these after validating they are arrays
          rules
          url_filters
        end

        def rules
          @rules ||=
            if @ruleset[:rules]&.any?
              @ruleset[:rules].map do |rule|
                Crawler::Data::Extraction::Rule.new(rule)
              end
            else
              []
            end
        end

        def url_filters
          @url_filters ||=
            if @ruleset[:url_filters]&.any?
              @ruleset[:url_filters].map do |filter|
                Crawler::Data::Extraction::UrlFilter.new(filter)
              end
            else
              []
            end
        end

        private

        def validate_ruleset
          if !@ruleset[:rules].nil? && !@ruleset[:rules].is_a?(Array)
            raise ArgumentError, 'Extraction ruleset rules must be an array'
          end

          return unless !@ruleset[:url_filters].nil? && !@ruleset[:url_filters].is_a?(Array)

          raise ArgumentError, 'Extraction ruleset url_filters must be an array'
        end
      end
    end
  end
end
