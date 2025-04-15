#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  class DocumentMapper
    class UnsupportedCrawlResultError < StandardError; end

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def create_doc(crawl_result)
      return create_html_doc(crawl_result) if crawl_result.html?

      return create_binary_file_doc(crawl_result) if crawl_result.content_extractable_file?

      # This error should never raise.
      # If this error is raised, something has gone wrong with crawl results in the coordinator.
      error = <<~LOG.squish
        Cannot create an ES doc from the crawl result for #{crawl_result.url}:
        Crawl result type #{crawl_result.class} not supported.
      LOG
      raise UnsupportedCrawlResultError, error
    end

    private

    def create_html_doc(crawl_result)
      {}.merge(
        core_fields(crawl_result),
        html_fields(crawl_result),
        url_components(crawl_result.url),
        extraction_rule_fields(crawl_result)
      )
    end

    def create_binary_file_doc(crawl_result)
      {}.merge(
        core_fields(crawl_result),
        binary_file_fields(crawl_result),
        url_components(crawl_result.url),
        extraction_rule_fields(crawl_result)
      )
    end

    def core_fields(crawl_result)
      {
        id: crawl_result.url_hash,
        last_crawled_at: crawl_result.start_time&.rfc3339
      }
    end

    def html_fields(crawl_result) # rubocop:disable Metrics/AbcSize
      remove_empty_values(
        title: crawl_result.document_title(limit: config.max_title_size),
        body: crawl_result.document_body(limit: config.max_body_size),
        meta_keywords: crawl_result.meta_keywords(limit: config.max_keywords_size),
        meta_description: crawl_result.meta_description(limit: config.max_description_size),
        meta_content: crawl_result.meta_tags_elastic(limit: config.max_elastic_tag_size),
        body_data: crawl_result.data_attributes_from_body(limit: config.max_data_attribute_size),
        links: crawl_result.links(limit: config.max_indexed_links_count),
        headings: crawl_result.headings(limit: config.max_headings_count),
        full_html: crawl_result.full_html(enabled: config.full_html_extraction_enabled)
      )
    end

    def binary_file_fields(crawl_result)
      remove_empty_values(
        file_name: crawl_result.file_name,
        content_length: crawl_result.content_length,
        content_type: crawl_result.content_type,
        _attachment: crawl_result.base64_encoded_content
      )
    end

    def url_components(url)
      url = Crawler::Data::URL.parse(url.to_s) unless url.is_a?(Crawler::Data::URL)
      path_components = url.path.split('/')
      remove_empty_values(
        url: url.to_s,
        url_scheme: url.scheme,
        url_host: url.host,
        url_port: url.inferred_port,
        url_path: url.path,
        url_path_dir1: path_components[1], # [0] is always empty since path starts with a /
        url_path_dir2: path_components[2],
        url_path_dir3: path_components[3]
      )
    end

    def extraction_rule_fields(crawl_result)
      rulesets = @config.extraction_rules[crawl_result.site_url.to_s] || []
      Crawler::ContentEngine::Extractor.extract(rulesets, crawl_result).symbolize_keys
    end

    # Accepts a hash and removes empty values from it
    def remove_empty_values(hash_object)
      hash_object.tap { |h| h.reject! { |_, value| value.blank? } }
    end
  end
end
