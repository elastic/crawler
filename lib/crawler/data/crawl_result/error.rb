# frozen_string_literal: true

require_dependency(File.join(__dir__, '..', 'crawl_result'))

module Crawler
  module Data
    class CrawlResult::Error < CrawlResult
      # Fake status code to be used for fatal internal errors
      FATAL_ERROR_STATUS = 599

      attr_reader :error, :suggestion_message

      def initialize(error:, status_code: FATAL_ERROR_STATUS, suggestion_message: nil, **kwargs)
        super(:status_code => status_code, **kwargs)
        @error = error
        @suggestion_message = suggestion_message
      end

      # Allow constructor to be called on concrete result classes
      public_class_method :new

      #---------------------------------------------------------------------------------------------
      def to_h
        super.merge(:error => error)
      end

      def to_s
        "<CrawlResult::Error: id=#{id}, status_code=#{status_code}, url=#{url}, error=#{error.inspect}>"
      end
    end
  end
end
