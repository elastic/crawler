#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  class DocumentMapper
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def document_fields(crawl_result) # rubocop:disable Metrics/AbcSize
      remove_empty_values(
        'title' => crawl_result.document_title(limit: config.max_title_size),
        'body_content' => crawl_result.document_body(limit: config.max_body_size),
        'meta_keywords' => crawl_result.meta_keywords(limit: config.max_keywords_size),
        'meta_description' => crawl_result.meta_description(limit: config.max_description_size),
        'links' => crawl_result.links(limit: config.max_indexed_links_count),
        'headings' => crawl_result.headings(limit: config.max_headings_count),
        'last_crawled_at' => crawl_result.start_time&.rfc3339
      )
    end

    def url_components(url)
      url = Crawler::Data::URL.parse(url.to_s) unless url.is_a?(Crawler::Data::URL)
      path_components = url.path.split('/')
      remove_empty_values(
        'url' => url.to_s,
        'url_scheme' => url.scheme,
        'url_host' => url.host,
        'url_port' => url.inferred_port,
        'url_path' => url.path,
        'url_path_dir1' => path_components[1], # [0] is always empty since path starts with a /
        'url_path_dir2' => path_components[2],
        'url_path_dir3' => path_components[3]
      )
    end

    def extract_by_rules(crawl_result, extraction_rules)
      rulesets = extraction_rules[crawl_result.site_url.to_s]
      Crawler::ContentEngine::Extractor.extract(rulesets, crawl_result)
    end

    private

    # Accepts a hash and removes empty values from it
    def remove_empty_values(hash_object)
      hash_object.tap { |h| h.reject! { |_, value| value.blank? } }
    end
  end
end
