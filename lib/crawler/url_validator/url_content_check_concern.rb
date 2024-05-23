#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module UrlValidator::UrlContentCheckConcern # rubocop:disable Style/ClassAndModuleChildren
    extend ActiveSupport::Concern

    def validate_url_content # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      # Fetch the seen URL unless it has already been fetched
      validate_url_request unless url_crawl_result

      # We did not follow the redirect, so can't parse it, let's warn the user
      return validation_warn_from_crawl_redirect if url_crawl_result.redirect?

      # Check content type
      return validation_fail_from_crawl_error unless url_crawl_result.is_a?(Crawler::Data::CrawlResult::HTML)

      # Parse HTML
      body = url_crawl_result.document_body
      if body.empty?
        warning = "The web page at #{url} did not return enough content to index."
        validation_warn(:url_content, warning)
      else
        validation_ok(
          :url_content,
          "Successfully extracted some content from #{url}.",
          title: url_crawl_result.document_title(limit: crawler_api_config.max_title_size),
          keywords: url_crawl_result.meta_keywords(limit: crawler_api_config.max_keywords_size),
          description: url_crawl_result.meta_description(limit: crawler_api_config.max_description_size),
          body_size_bytes: body.bytesize
        )
      end

      # Check if we have any links to follow
      links = url_crawl_result.links(limit: 10)
      if links.any?
        validation_ok(
          :url_content,
          "Successfully extracted some links from #{url}.",
          links_sample: links
        )
      else
        validation_warn(:url_content, <<~MESSAGE)
          The web page at #{url} has no links in it at all (this excludes any links
          that have 'rel="nofollow"' set).
          This means we will have no content to index other than this one page.
        MESSAGE
      end
    end

    #-------------------------------------------------------------------------------------------------
    def validation_warn_from_crawl_redirect
      location = url_crawl_result.location.to_s
      validation_warn(:url_content, <<~MESSAGE, location:)
        The web page at #{url} redirected us to #{location},
        please make sure the destination page contains some indexable
        content and is allowed by crawl rules before starting your crawl.
      MESSAGE
    end

    #-------------------------------------------------------------------------------------------------
    def validation_fail_from_crawl_error
      error_happened =
        if url_crawl_result.instance_of?(Crawler::Data::CrawlResult::Error)
          "an unexpected error occurred: #{url_crawl_result.error}"
        else
          'the server returned data that was not HTML'
        end

      validation_fail(:url_content, <<~MESSAGE, content_type: url_crawl_result.content_type)
        When we fetched the web page at #{url}, #{error_happened}.
        #{url_crawl_result.suggestion_message}
      MESSAGE
    end
  end
end
