#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

java_import org.htmlunit.TextPage

require_dependency(File.join(__dir__, 'base'))

module Crawler
  module Http
    module Response
      class HtmlUnit < Base
        def initialize(response:, **kwargs)
          @response = response

          super(**kwargs)
        end

        def type
          :html_unit
        end

        def release_connection
          # not required for HtmlUnit
        end

        def body
          content =
            if @response.class == Java::OrgHtmlunit::TextPage
              # for robots.txt
              @response.content
            else
              @response.as_xml
            end

          # asXml adds a heap of line breaks and stuff that we want to remove
          # white space is handled during content extraction later
          content.gsub(/[\n\r]/, '')
        end

        def web_response
          @web_response ||= @response.getWebResponse
        end

        def code
          web_response.getStatusCode
        end

        def reason_phrase
          web_response.getStatusMessage
        end

        def [](key)
          v = headers[key.downcase]
          v.is_a?(Array) ? v.first : v
        end

        def headers
          @headers ||= aggregate_headers(web_response.getResponseHeaders)
        end

        def content_type
          web_response.getContentType || headers['content-type']
        end
      end
    end
  end
end
