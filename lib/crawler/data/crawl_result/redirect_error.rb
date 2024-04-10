# frozen_string_literal: true

require_dependency(File.join(__dir__, 'error'))

module Crawler
  module Data
    module CrawlResult
      class RedirectError < CrawlResult::Error
        def initialize(**kwargs)
          suggestion = <<~EOF
            Check the URL content in your browser and make sure it is something
            the crawler could understand.
          EOF

          super(suggestion_message: suggestion, **kwargs)
        end
      end
    end
  end
end
