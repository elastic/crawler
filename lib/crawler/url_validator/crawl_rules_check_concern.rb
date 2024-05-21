# frozen_string_literal: true

module Crawler::UrlValidator::CrawlRulesCheckConcern
  extend ActiveSupport::Concern

  def validate_crawl_rules
    rule_engine = Crawler::RuleEngine::Elasticsearch.new(crawler_api_config)
    outcome = rule_engine.crawl_rules_outcome(normalized_url)
    rule = outcome.details[:rule]

    if outcome.allowed?
      validation_ok(:crawl_rules, 'The URL is allowed by one of the crawl rules', rule: rule.source)
    elsif rule
      validation_fail(:crawl_rules, 'The URL is denied by a crawl rule', rule: rule.source)
    else
      # This should never happen, but we're including it here to be safe
      validation_fail(:crawl_rules, 'The URL is denied because it did not match any rules')
    end
  end
end
