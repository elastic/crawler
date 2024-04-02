# frozen_string_literal: true

module Crawler::RuleEngine
  class Base
    attr_reader :config

    delegate :domain_allowlist, :robots_txt_service, :to => :config

    def initialize(config)
      raise ArgumentError, 'Invalid config' unless config.is_a?(Crawler::API::Config)
      @config = config
    end

    def discover_url_outcome(url)
      raise ArgumentError, 'Needs a Crawler::Data::URL object' unless url.is_a?(Crawler::Data::URL)

      unless domain_allowlist.include?(url.domain)
        return denied_outcome(:domain_filter_denied, :domains => domain_allowlist)
      end

      robots_txt_outcome = robots_txt_service.url_disallowed_outcome(url)
      if robots_txt_outcome.disallowed?
        return denied_outcome(:robots_txt_disallowed, robots_txt_outcome.disallow_message)
      end

      allowed_outcome
    end

    def output_crawl_result_outcome(crawl_result)
      raise ArgumentError, 'Needs a Crawler::Data::CrawlResult object' unless crawl_result.is_a?(Crawler::Data::CrawlResult)

      return denied_outcome(:content_type_denied, crawl_result.error) if crawl_result.unsupported_content_type?
      return denied_outcome(:fatal_error_denied, crawl_result.error) if crawl_result.fatal_error?
      return denied_outcome(:noindex_meta_denied) if crawl_result.html? && crawl_result.meta_noindex?

      if crawl_result.redirect? && crawl_result.redirect_count > config.max_redirects
        error = "Too many redirects (#{crawl_result.redirect_count}) while trying to download the page at #{crawl_result.original_url.inspect}"
        return denied_outcome(:too_many_redirects, error)
      end

      allowed_outcome
    end

    private

    def denied_outcome(deny_reason, *args)
      Crawler::Data::RuleEngineOutcome.public_send(deny_reason, *args)
    end

    def allowed_outcome(allow_reason = :always_allowed, *args)
      Crawler::Data::RuleEngineOutcome.public_send(allow_reason, *args)
    end
  end
end
