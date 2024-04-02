# frozen_string_literal: true

require_dependency(File.join(__dir__, '..', 'crawl_result'))

# The base class for all successful responses
module Crawler
  module Data
    class CrawlResult::Success < CrawlResult
      VALID_STATUS_CODES = 200..299

      attr_reader :content

      def initialize(status_code:, content:, **kwargs)
        super(:status_code => status_code, **kwargs)

        unless status_code.in?(VALID_STATUS_CODES)
          error = "Successful responses have to have a 2xx response code, received #{status_code.inspect}"
          raise ArgumentError, error
        end

        @content = content
      end
    end
  end
end
