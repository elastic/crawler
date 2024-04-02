# frozen_string_literal: true

module Crawler
  class RobotsTxtService
    class MissingRobotsTxt < StandardError; end

    class << self
      def always_allow
        AlwaysAllow.new
      end
    end

    attr_reader :user_agent

    def initialize(user_agent:)
      @user_agent = user_agent
      @store = {}
    end

    def registered?(domain)
      store.key?(domain.to_s)
    end

    def register_crawl_result(domain, crawl_result)
      store[domain.to_s] =
        if crawl_result.status_code < 300
          Crawler::RobotsTxtParser.new(crawl_result.content, :base_url => domain.to_s, :user_agent => user_agent)
        else
          Crawler::RobotsTxtParser::Failure.new(:base_url => domain.to_s, :status_code => crawl_result.status_code)
        end
    end

    def parser_for_domain(domain)
      store[domain.to_s]
    end

    def url_disallowed_outcome(url)
      domain = url.domain

      unless registered?(domain)
        raise MissingRobotsTxt, "No robots.txt has yet been registered for the domain #{domain}"
      end

      parser = store.fetch(domain.to_s)

      if parser.allow_none?
        DisallowedOutcome.new(true, parser.allow_none_reason)
      elsif parser.allowed?(url.path)
        DisallowedOutcome.new(false, nil)
      else
        DisallowedOutcome.new(true, 'Disallowed by robots.txt')
      end
    end

    def sitemaps
      store.each_with_object([]) do |(_, parser), out|
        parser.sitemaps.each do |sitemap|
          out << sitemap
        end
      end
    end

    private

    attr_reader :store

    class AlwaysAllow < RobotsTxtService
      def initialize(*); end

      def registered?(*)
        true
      end

      def register_crawl_result(*)
        raise NotImplementedError
      end

      def url_disallowed_outcome(*)
        DisallowedOutcome.new(false, nil)
      end

      def sitemaps
        []
      end
    end

    DisallowedOutcome = Struct.new(:disallowed?, :disallow_message) do
      def allowed?
        !disallowed?
      end
    end
  end
end
