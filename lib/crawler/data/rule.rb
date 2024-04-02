# frozen_string_literal: true

module Crawler
  module Data
    class Rule
      ALLOW = :allow
      DENY = :deny
      REGEX_TIMEOUT = 1.second

      SUPPORTED_POLICIES = [ALLOW, DENY].freeze

      attr_reader :policy, :source

      def initialize(policy, url_pattern:, source: nil)
        unless SUPPORTED_POLICIES.include?(policy)
          raise ArgumentError, "policy: #{policy.inspect} is not a supported value"
        end

        unless url_pattern.is_a?(Regexp)
          raise ArgumentError, "url_pattern: must be a Regexp, it was #{url_pattern.class}"
        end

        @policy = policy
        @url_pattern = url_pattern
        @source = source
      end

      def url_match?(url)
        Timeout.timeout(REGEX_TIMEOUT) do
          @url_pattern.match?(url.to_s)
        end
      end
    end
  end
end
