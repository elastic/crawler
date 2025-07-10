#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module ContentEngine
    module Extractor
      REGEX_TIMEOUT = 0.5 # seconds

      # Extract content from a crawl result based on configured content extraction rules
      # If a ruleset's URL filter matches the crawl result's URL, we execute every rule in that ruleset.
      def self.extract(rulesets, crawl_result)
        fields = {}

        rulesets.each do |ruleset|
          next unless match_url_filters?(ruleset, crawl_result)

          fields.merge!(execute_rules(ruleset, crawl_result))
        end

        fields
      end

      # Execute every rule from a content extraction ruleset
      def self.execute_rules(ruleset, crawl_result)
        fields = {}

        ruleset.rules.each do |rule|
          field_name = rule.field_name

          case rule.action
          when Crawler::Data::Extraction::Rule::ACTION_TYPE_SET
            fields[field_name] = rule.value
          when Crawler::Data::Extraction::Rule::ACTION_TYPE_EXTRACT
            fields[field_name] = cast_result(rule, extract_from_crawl_result(rule, crawl_result))
          end
        end

        fields
      end

      # Using the provided rule, extract content from the crawl result
      # Supports extraction from the URL string, and extraction from the HTML result
      def self.extract_from_crawl_result(rule, crawl_result)
        if rule.source == Crawler::Data::Extraction::Rule::SOURCES_URL
          Timeout.timeout(REGEX_TIMEOUT) do
            return crawl_result.url.extract_by_regexp(Regexp.new(rule.selector))
          end
        end

        return [] unless crawl_result.is_a?(Crawler::Data::CrawlResult::HTML)

        case rule.type
        when Crawler::Data::Extraction::Rule::SELECTOR_TYPE_CSS
          crawl_result.extract_by_css_selector(rule.selector, [])
        when Crawler::Data::Extraction::Rule::SELECTOR_TYPE_XPATH
          crawl_result.extract_by_xpath_selector(rule.selector, [])
        else
          raise ArgumentError,
                "Unexpected extraction rule selector type '#{rule.type}' for selector '#{rule.selector}'"
        end
      end

      def self.cast_result(rule, occurrences)
        return occurrences if rule.join_as == Crawler::Data::Extraction::Rule::JOINS_ARRAY

        occurrences.join(' ')
      end

      # Checks the configured URL filter against the crawl result's URL
      # Returns all associated rules for each match
      def self.match_url_filters?(ruleset, crawl_result)
        filtering_rules = ruleset.url_filtering_rules

        # if there are no filters then all URLs match
        return true if filtering_rules.empty?

        filtering_rules.any? do |fr|
          match = fr.url_match?(crawl_result.url.to_s)
          match
        end
      end
    end
  end
end
