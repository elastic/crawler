# frozen_string_literal: true

module Crawler
  module Data
    # CrawlTask represents a single resource that is intended be crawled, i.e. a page that should
    # be fetched and extracted.
    class CrawlTask
      AUTHORIZATION_HEADER_KEY = 'Authorization'

      attr_reader :url   # URL object representing the target to fetch.
      attr_reader :depth # Positive integer. The number of ancestors including itself.
      attr_reader :type  # An URL type value (content, sitemap, feed, etc)
      attr_reader :redirect_chain # A list of URLs we have visited before being redirected here
      attr_accessor :authorization_header # This value contains sensitive data so it will not be stored in ES but instead set at runtime.

      def initialize(url:, type:, depth:, redirect_chain: [])
        @url = url
        @type = type.to_sym
        @depth = depth.to_i
        @redirect_chain = redirect_chain
      end

      def inspect
        "<CrawlTask: url=#{url}, type=#{type}, depth=#{depth}, redirect_count=#{redirect_chain.length}, auth=#{auth_type || 'none'}>"
      end

      def auth_type
        authorization_header[:type] if authorization_header.is_a?(Hash)
      end

      def http_url_with_auth?
        url.scheme == 'http' && authorization_header
      end

      def ==(other)
        to_h == other.to_h
      end

      def headers
        return unless authorization_header.is_a?(Hash)

        {
          AUTHORIZATION_HEADER_KEY => authorization_header[:value]
        }
      end

      #---------------------------------------------------------------------------------------------
      # Serialization/deserialization methods used for persisting queue items
      #---------------------------------------------------------------------------------------------

      # Returns a unique identifier used to persist the object into Elasticsearch
      def unique_id
        @unique_id ||= Digest::SHA1.hexdigest(to_h.to_json)
      end

      # Returns a hash representation of a task ready to be persisted into Elasticsearch
      def to_h
        {
          :url => url.to_s,
          :type => type.to_s,
          :depth => depth.to_i,
          :redirect_chain => redirect_chain.map(&:to_s)
        }
      end

      # Returns a CrawlTask object based on a hash loaded from Elasticsearch
      def self.load(data)
        CrawlTask.new(
          :url => URL.parse(data.fetch('url')),
          :type => data.fetch('type'),
          :depth => data.fetch('depth'),
          :redirect_chain => data['redirect_chain']
        )
      end

      #---------------------------------------------------------------------------------------------
      def sitemap?
        type == :sitemap
      end

      def content?
        type == :content
      end

      def robots_txt?
        type == :robots_txt
      end
    end
  end
end
