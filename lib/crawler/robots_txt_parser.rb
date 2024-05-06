#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  class RobotsTxtParser
    java_import 'crawlercommons.robots.SimpleRobotRulesParser'

    def self.robots_txt_to_byte_array(content)
      bytes = content.bytes

      # Fix problem where people were serving HTML 404s for robots.txt,
      # and that HTML contained non-USASCII characters, which are illegal in robots.txt.
      # Also, (Java) bytes by definition have to be in the range -128..127.
      bytes.select! { |b| b <= 127 }

      bytes.to_java(:byte)
    end

    def initialize(content, base_url:, user_agent: 'Elastic-Crawler')
      @base_url = Crawler::Data::URL.parse(base_url)
      @robots_rules = robots_rules_parser.parse_content(
        base_url,
        self.class.robots_txt_to_byte_array(content),
        'text/html',
        user_agent
      )
    end

    def crawl_delay
      delay_ms = robots_rules.crawl_delay
      delay_ms.negative? ? nil : delay_ms / 1000
    end

    def sitemaps
      robots_rules.sitemaps.to_a
    end

    def allowed?(path)
      url = base_url.join(path).to_s
      robots_rules.is_allowed(url)
    end

    def allow_all?
      robots_rules.is_allow_all
    end

    def allow_none?
      robots_rules.is_allow_none && allow_none_reason
    end

    def allow_none_reason; end

    private

    attr_reader :robots_rules, :base_url

    def robots_rules_parser
      Java::CrawlercommonsRobots::SimpleRobotRulesParser.new.tap do |parser|
        # This effectively removes the crawl delay handling built into the parser.
        parser.set_max_crawl_delay(Java::JavaLang::Long::MAX_VALUE)
      end
    end

    class Failure < RobotsTxtParser
      def initialize(base_url:, status_code:) # rubocop:disable Lint/MissingSuper
        @status_code = status_code
        @base_url = Crawler::Data::URL.parse(base_url)
        @robots_rules = Java::CrawlercommonsRobots::SimpleRobotRulesParser.new.failed_fetch(status_code)
      end

      def allow_none_reason
        "Allow none because robots.txt responded with status #{@status_code}"
      end
    end
  end
end
