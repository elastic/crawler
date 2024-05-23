#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

module Faux
  module Element
    class Robots < Base

      def call(env)
        @rules = []
        super
      end

      def sitemap(url_or_path, options = {})
        if options[:relative] == true
          url_or_path = absolute_url_for(url_or_path)
        end
        @rules << "Sitemap: #{url_or_path}\n"
      end

      def method_missing(name, *args, &block)
        @rules << "#{normalize_name(name)}: #{args.first}\n"
      end

      def response_body
        @rules
      end

      def response_headers
        @headers.merge!({'Content-Type' => 'text/plain'})
        super
      end

      private

      def normalize_name(name)
        name.to_s.gsub('_', '-').capitalize
      end
    end
  end
end
