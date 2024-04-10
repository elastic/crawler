# frozen_string_literal: true

require_dependency(File.join(__dir__, 'error'))

module Crawler
  module Data
    module CrawlResult
      class UnsupportedContentType < Error
        def initialize(content_type:, error: nil, **kwargs)
          suggestion = <<~EOF
            Check the URL content in your browser and make sure it is something
            the crawler could understand.
          EOF

          super(
            content_type: content_type,
            error: error || "Unsupported content type: #{content_type}",
            suggestion_message: suggestion,
            **kwargs
          )
        end
      end
    end
  end
end
