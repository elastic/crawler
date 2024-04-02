# frozen_string_literal: true

require 'addressable'
require 'digest'

module Crawler
  module Data
    class URL < Addressable::URI
      SUPPORTED_SCHEMES = %w[http https].freeze

      # Returns a unique hash of the normalized version of this URL
      #
      # Beware: if you change this method's behavior, the crawler will potentially lose all of its
      #         state dependent on URL hash values, etc.
      #
      def normalized_hash
        @normalized_hash ||= Digest::SHA1.hexdigest(normalized_url)
      end

      # Returns a normalized version of this URL
      #
      # Beware: if you change this method's behavior, it will change our hashing algorithm and the
      #         crawler will potentially lose all of its state dependent on URL hash values, etc.
      #
      def normalized_url
        @normalized_url ||= dup.tap do |url|
          url.fragment = nil
          url.normalize!
        end
      end

      # Returns a normalized version of the domain for this URL
      def domain
        @domain ||= Crawler::Data::Domain.new(normalized_url.to_s)
      end

      # Returns the domain name for the URL, stripping out the path/query/fragment
      def domain_name
        @domain_name ||= dup.tap do |url|
          url.path = url.query = url.fragment = nil
        end.to_s
      end

      # Returns +true+ if the URL scheme is supported by the crawler (HTTP/HTTPS)
      def supported_scheme?
        SUPPORTED_SCHEMES.include?(scheme)
      end

      # Returns a number of path segments for the URL (/a/b/c => 3)
      def path_segments_count
        path.count('/')
      end

      # Returns the number of query parameters for a given URL (/x?foo=1&bar=2 => 2)
      def params_count
        query_values ? query_values.count : 0
      end

      # Returns a java URL object for this url
      def java_url
        Java::JavaNet::URL.new(to_s)
      end

      # Match a regexp with URL
      # Returns an array of captures if regex groups are used  e.g. /foo=([0-9])/ where ([0-9]) is a group
      # Returns an array with a single element if regex groups are not used and the match was successful
      #
      # @param [Regexp] regexp
      # @return [Array<String>]
      def extract_by_regexp(regexp)
        raise ArgumentError.new 'regexp has to be a Regexp instance' unless regexp.kind_of?(Regexp)

        match_data = regexp.match(normalized_url)
        return [] unless match_data

        # return capture is regex groups are used
        captures = match_data.captures
        return captures unless captures.empty?

        # return a successulf match as a single element array
        match_data.to_a
      end
    end
  end
end
