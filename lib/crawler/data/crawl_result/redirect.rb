# frozen_string_literal: true

require_dependency(File.join(__dir__, '..', 'crawl_result'))

module Crawler
  module Data
    class CrawlResult::Redirect < CrawlResult
      VALID_STATUS_CODES = 300..399

      attr_reader :redirect_chain, :location

      def initialize(status_code:, location:, redirect_chain:, **kwargs)
        super(:status_code => status_code, **kwargs)

        unless status_code.in?(VALID_STATUS_CODES)
          error = "Redirects have to have a 3xx response code, received #{status_code.inspect}"
          raise ArgumentError, error
        end

        unless location.kind_of?(Crawler::Data::URL)
          raise ArgumentError, 'Location needs to be a Crawler URL object!'
        end

        @location = location
        @redirect_chain = redirect_chain
      end

      # Allow constructor to be called on concrete result classes
      public_class_method :new

      #---------------------------------------------------------------------------------------------
      def to_h
        super.merge(
          :location => location,
          :redirect_chain => redirect_chain
        )
      end

      def to_s
        "<CrawlResult::Redirect: id=#{id}, status_code=#{status_code}, original_url=#{original_url}, location=#{location}, redirect_count=#{redirect_count}>"
      end

      def original_url
        redirect_chain.first || url
      end

      def redirect_count
        redirect_chain.size + 1
      end
    end
  end
end
