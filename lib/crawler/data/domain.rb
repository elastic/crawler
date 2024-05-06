#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Data
    class Domain
      attr_reader :scheme, :host, :port

      def initialize(domain)
        @url = Crawler::Data::URL.parse(domain)
        @scheme = url.scheme
        @host = url.host
        @port = url.port || standard_port_for_scheme(url.scheme)
      end

      def raw_url
        url
      end

      def robots_txt_url
        url.join('/robots.txt')
      end

      def standard_port_for_scheme(scheme)
        case scheme
        when 'http' then 80
        when 'https' then 443
        end
      end

      def ==(other)
        to_s == other.to_s
      end

      def to_s
        "#{scheme}://#{host}:#{port}"
      end

      private

      attr_reader :url
    end
  end
end
