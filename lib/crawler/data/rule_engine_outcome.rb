#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Data
    class RuleEngineOutcome
      class << self
        def always_allowed
          AllowedOutcome.new
        end

        def fatal_error_denied(error)
          DeniedOutcome.new(:fatal_error_denied, message: "Error: #{error}")
        end

        def too_many_redirects(error)
          DeniedOutcome.new(:too_many_redirects, message: error)
        end

        def content_type_denied(error)
          DeniedOutcome.new(:content_type_denied, message: error)
        end

        def purge_crawl_allowed
          AllowedOutcome.new(message: 'Always allowing for purge crawls')
        end

        def noindex_meta_denied
          DeniedOutcome.new(
            :rule_engine_denied,
            message: 'Page contains <meta name="robots" content="noindex">'
          )
        end

        def domain_filter_denied(allow_list)
          DeniedOutcome.new(
            :domain_filter_denied,
            message: "Does not match allowed domains: #{allow_list[:domains].join(', ')}"
          )
        end

        def robots_txt_disallowed(message)
          DeniedOutcome.new(:robots_txt_disallowed, message: message)
        end

        def crawl_rule_denied(rule)
          DeniedOutcome.new(
            :rule_engine_denied,
            message: "Denied by crawl rule: #{rule.source}",
            details: { rule: rule }
          )
        end

        def crawl_rule_allowed(rule)
          AllowedOutcome.new(
            message: "Allowed by crawl rule: #{rule.source}",
            details: { rule: rule }
          )
        end

        def crawl_rule_timeout(options)
          DeniedOutcome.new(
            :rule_engine_denied,
            message: format('Timeout while applying crawl rule: %<source>s', options)
          )
        end

        def no_crawl_rule_match_denied(url)
          DeniedOutcome.new(
            :rule_engine_denied,
            message: "Denying discovery of URL #{url}, could not find matching crawl rule"
          )
        end
      end

      attr_reader :message, :details

      def denied?
        raise NotImplementedError
      end

      def allowed?
        raise NotImplementedError
      end
    end

    class DeniedOutcome < RuleEngineOutcome
      attr_reader :deny_reason

      def initialize(deny_reason, message:, details: {}) # rubocop:disable Lint/MissingSuper
        @deny_reason = deny_reason
        @message = message
        @details = details
      end

      def denied?
        true
      end

      def allowed?
        false
      end
    end

    class AllowedOutcome < RuleEngineOutcome
      def initialize(message: nil, details: {}) # rubocop:disable Lint/MissingSuper
        @message = message
        @details = details
      end

      def denied?
        false
      end

      def allowed?
        true
      end
    end
  end
end
