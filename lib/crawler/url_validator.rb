#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  class UrlValidator
    class Error < StandardError; end
    class InvalidChecksError < Error; end
    class InvalidCrawlConfigError < Error; end

    # Domain-scoped checks that do not need an configuration
    DOMAIN_LEVEL_CHECKS = %i[
      url
      dns
      tcp
      robots_txt
      url_request
      url_content
    ].freeze
    DEFAULT_DOMAIN_LEVEL_CHECKS = DOMAIN_LEVEL_CHECKS

    # index-scoped checks including index level domains and crawl rules
    INDEX_LEVEL_CHECKS = %i[
      url
      domain_access
      domain_uniqueness
      crawl_rules
      dns
      tcp
      robots_txt
      url_request
      url_content
    ].freeze
    DEFAULT_INDEX_LEVEL_CHECKS = (INDEX_LEVEL_CHECKS - [:domain_uniqueness]).freeze

    # Network-related check timeouts in seconds
    DNS_CHECK_TIMEOUT = 5
    TCP_CHECK_TIMEOUT = 2
    HTTP_CHECK_TIMEOUT = 5

    # Include check definitions
    (DOMAIN_LEVEL_CHECKS + INDEX_LEVEL_CHECKS).uniq.each do |check|
      concern_name = "#{check}_check_concern".camelize
      require "crawler/url_validator/#{concern_name.underscore}"
      concern_name = "Crawler::UrlValidator::#{concern_name}"
      include(concern_name.constantize)
    end

    # The crawl stage name to be used for requests made by the validator
    CRAWL_STAGE = :url_validator

    CRAWL_CONFIG_OVERRIDES = {
      crawl_stage: CRAWL_STAGE,
      output_sink: :null,

      # Tighter timeouts
      connect_timeout: TCP_CHECK_TIMEOUT,
      socket_timeout: HTTP_CHECK_TIMEOUT,
      request_timeout: HTTP_CHECK_TIMEOUT
    }.freeze

    #-------------------------------------------------------------------------------------------------
    attr_reader :raw_url, :checks, :results, :url_crawl_result

    def initialize(url:, crawl_config:, checks: nil)
      @crawl_config = crawl_config
      # Default to running all checks for the given context
      checks ||= valid_checks

      # We always run the URL validation check
      requested_checks = [:url] + checks.map(&:to_sym)

      @checks = (requested_checks & valid_checks).uniq
      @raw_url = url
      @results = []
    end

    #-------------------------------------------------------------------------------------------------
    # Returns a list of check names that are valid for a given validator configuration
    def valid_checks
      DOMAIN_LEVEL_CHECKS
    end

    #-------------------------------------------------------------------------------------------------
    # Validates a given domain, returns +true+ if the domain is valid, +false+ otherwise
    # Detailed results could be retrieved by calling `#results`
    def valid?
      validate if results.empty?
      !any_failed_results?
    end

    # Performs all checks and populates the `#results` array
    def validate
      results.clear
      checks.each do |check_name|
        perform_check(check_name)
        break if any_failed_results?
      end
    end

    def url
      @url ||= ::Crawler::Data::URL.parse(raw_url)
    end

    def normalized_url
      url.normalized_url
    rescue Addressable::URI::InvalidURIError
      raw_url
    end

    def failed_checks
      results.select(&:failure?)
    end

    private

    def any_failed_results?
      results.any?(&:failure?)
    end

    def validation_ok(name, comment, details = {})
      results << Result.new(
        name:,
        result: :ok,
        comment: comment.squish,
        details:
      )
    end

    def validation_warn(name, comment, details = {})
      results << Result.new(
        name:,
        result: :warning,
        comment: comment.squish,
        details:
      )
    end

    def validation_fail(name, comment, details = {})
      results << Result.new(
        name:,
        result: :failure,
        comment: comment.squish,
        details:
      )
    end

    def perform_check(check_name)
      check_method = :"validate_#{check_name}"
      raise ArgumentError, "Invalid check name: #{check_name.inspect}" unless respond_to?(check_method, true)

      send(check_method)
    end

    def http_executor
      @http_executor ||= Crawler::HttpExecutor.new(crawler_api_config)
    end

    def proxy_configured?
      !!crawler_api_config.http_proxy_host
    end

    def crawler_api_config
      @crawl_config
    end
  end
end
