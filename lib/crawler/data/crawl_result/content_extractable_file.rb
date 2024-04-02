# frozen_string_literal: true

require 'digest'

require_dependency(File.join(__dir__, 'success'))

module Crawler
  module Data
    class CrawlResult::ContentExtractableFile < CrawlResult::Success
      # Allow constructor to be called on concrete result classes
      public_class_method :new

      def content_hash
        @content_hash ||= Digest::SHA1.hexdigest(content)
      end

      def base64_encoded_content
        Base64.strict_encode64(content)
      end
    end
  end
end
