#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

module Faux
  module Element
    class Base
      include Faux::Helpers::Url

      attr_reader :content_block, :env, :options

      def initialize(options, &content_block)
        @content_block = content_block
        @options = options
        @status = 200
      end

      def call(env)
        @env = env
        @headers = {}

        instance_exec(&content_block) if content_block
        [response_status, response_headers, response_body]
      end

      # Get methods (used in `call`)
      def response_status
        @status
      end

      def response_headers
        unless @headers.keys.find { |k| k.downcase == 'content-type' }
          @headers['Content-Type'] = 'text/html'
        end
        @headers
      end

      # Set methods (used by DSL)
      def status(code)
        @status = code.to_i
      end

      def headers(headers_hash)
        @headers.merge!(headers_hash || {})
      end

      def response_body
        raise 'Must be defined in a subclass'
      end

      def redirect(location, options = {})
        @status = options[:permanent] ? 301 : 302
        @headers['Location'] = options[:relative] ? location : absolute_url_for(location)
      end
    end
  end
end
