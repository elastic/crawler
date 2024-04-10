# frozen_string_literal: true

require_dependency(File.join(__dir__, 'error'))

module Crawler
  module Data
    module CrawlResult
      class HttpAuthDisallowedError < Error
        def initialize(error: nil, **kwargs)
          suggestion_message = <<~EOF
            Set `crawler.security.auth.allow_http: true` if you want to
            allow authenticated crawling of non-HTTPS URLs.
          EOF

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
