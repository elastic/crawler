#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Data
    # An object representing an HTML link from one page to another
    class Link
      attr_reader :base_url, :link, :node

      # There are two ways to pass a link in:
      # - `link` - a string representation of a link
      # - `node` - a Nokogiri::XML::Element object
      def initialize(base_url:, node: nil, link: nil) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        raise ArgumentError, 'Base URL needs to be a URL object' unless base_url.is_a?(URL)
        raise ArgumentError, 'Needs an node or a string link argument' unless node || link
        raise ArgumentError, 'The :link argument needs to be a String' if link && !link.is_a?(String)

        if node && !node.is_a?(Nokogiri::XML::Element)
          raise ArgumentError,
                'The :node argument needs to be a Nokogiri::XML::Element'
        end
        raise ArgumentError, 'Needs only one link argument' if node && link

        @base_url = base_url
        @node = node
        @link = node ? node['href'] : link
        @error = nil
      end

      def to_s
        "<Link: base_url=#{base_url}; link=#{link.inspect}; node=#{node.inspect}; error=#{error.inspect}>"
      end

      # Make it possible to compare links and use them as keys in hashes and sets
      def hash
        @hash ||= [base_url, link, node].map(&:to_s).map(&:hash).sum # rubocop:disable Performance/Sum
      end

      def ==(other)
        other.hash == hash
      end

      def ===(other_link)
        other_link.hash == hash
      end

      def eql?(other)
        other.hash == hash
      end

      # Returns an absolute URL for the link destination
      # Raises an Addressable::URI::InvalidURIError exception if the link is invalid or empty
      # You can call +valid?+ before converting a link to a URL if you need to make sure it is valid
      def to_url
        unless link
          error = "Link has no href attribute#{node && ": #{node}"}"
          raise Addressable::URI::InvalidURIError, error
        end

        base_url.join(link.strip)
      end

      # Returns +true+ if the link is valid and could be converted to an absolute URL
      # Returns +false+ otherwise, along with setting the error value on the object
      def valid?
        to_url
        true
      rescue Addressable::URI::InvalidURIError => e
        @error = e.to_s
        false
      end

      # Returns an error message for invalid URLs, +nil+ otherwise
      def error
        # Run the validation code if we don't have an error
        valid? unless @error
        @error
      end

      # Returns an array with all the values of the rel attribute for the link
      # See https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel for details
      def rel
        node ? node['rel'].to_s.squish.downcase.split : []
      end

      # Returns +true+ if the link contains a rel=nofollow attribute
      def rel_nofollow?
        rel.include?('nofollow')
      end
    end
  end
end
