# frozen_string_literal: true
#
module Crawler
  module Data
    class SeenUrls
      def initialize
        @seen_urls = Concurrent::Set.new
      end

      def clear
        @seen_urls.clear
      end

      def count
        @seen_urls.size
      end

      def delete(url)
        @seen_urls.delete(url_hash(url))
      end

      # A method called when the crawler needs to stop and persist its state
      def save
        # nothing to do by default
      end

      # Tries to add an item to the set
      # Returns +true+ if this is a new URL and we should visit it
      # Returns +false+ if we have already seen this URL
      def add?(url)
        !!@seen_urls.add?(url_hash(url))
      end

      private

      def url_hash(url)
        raise ArgumentError, 'Needs a URL' unless url.kind_of?(Crawler::Data::URL)
        url.normalized_hash
      end

    end
  end
end
