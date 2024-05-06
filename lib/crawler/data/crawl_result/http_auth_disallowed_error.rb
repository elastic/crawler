#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency(File.join(__dir__, 'error'))

module Crawler
  module Data
    module CrawlResult
      class HttpAuthDisallowedError < Error
        def initialize(error: nil, **kwargs)
          suggestion_message = <<~MSG
            Set `crawler.security.auth.allow_http: true` if you want to
            allow authenticated crawling of non-HTTPS URLs.
          MSG

          super(
            error: error || 'Authenticated crawling of non-HTTPS URLs is not allowed',
            suggestion_message: suggestion_message,
            **kwargs
          )
        end
      end
    end
  end
end
