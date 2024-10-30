#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Http
    module Response
      class Base

        DEFAULT_BUFFER_SIZE = 4_096
        DEFAULT_MAX_RESPONSE_SIZE = 10_485_760 # 10 MB

        attr_reader :url, :request_start_time, :request_end_time

        def initialize(url:, request_start_time:, request_end_time:)
          raise ArgumentError, 'Need a Crawler URL object!' unless url.is_a?(Crawler::Data::URL)

          @request_start_time = request_start_time
          @request_end_time = request_end_time
        end

        def type
          :undefined
        end

        def content_length
          headers['content-length'].to_i
        end

        def mime_type
          (content_type || '').downcase.split(';').first.presence&.strip
        end

        def time_since_request_start
          Time.now - request_start_time
        end

        def redirect?
          code >= 300 && code <= 399
        end

        def error?
          code >= 400
        end

        def unsupported_method?
          code == 405
        end

        def redirect_location
          url.join(headers['location'])
        end

        private

        def aggregate_headers(raw_headers)
          raw_headers.each_with_object({}) do |h, o|
            key = h.get_name.downcase

            if o.key?(key)
              o[key] = Array(o[key]) unless o[key].is_a?(Array)
              o[key].push(h.get_value)
            else
              o[key] = h.get_value
            end
          end
        end
      end
    end
  end
end
