#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'active_support/core_ext/string/filters'
require_dependency File.join(__dir__, '..', 'response', 'apache')
require_dependency(File.join(__dir__, 'base'))

module Crawler
  module Http
    module Response
      class Apache < Base
        java_import org.apache.hc.core5.util.ByteArrayBuffer
        java_import org.apache.hc.core5.http.ContentType
        java_import org.apache.hc.core5.http.message.StatusLine

        def initialize(apache_response:, **kwargs)
          @response = apache_response
          @http_entity = apache_response.entity

          super(**kwargs)
        end

        def release_connection
          response.close
        end

        def body(
          max_response_size: DEFAULT_MAX_RESPONSE_SIZE,
          request_timeout: nil,
          default_encoding: Encoding.default_external
        )
          return @body if defined?(@body)

          return unless http_entity.content

          content_bytes = consume_http_entity(
            max_response_size:,
            request_timeout:
          )

          encoding = detect_encoding_from_content_charset || default_encoding
          @body = String.from_java_bytes(content_bytes, encoding)
        end

        def apache_status_line
          @apache_status_line ||= StatusLine.new(response)
        end

        def code
          apache_status_line.status_code
        end

        def reason_phrase
          apache_status_line.reason_phrase
        end

        def [](key)
          v = headers[key.downcase]
          v.is_a?(Array) ? v.first : v
        end

        def headers
          @headers ||= response.headers.each_with_object({}) do |h, o|
            key = h.get_name.downcase

            if o.key?(key)
              o[key] = Array(o[key]) unless o[key].is_a?(Array)
              o[key].push(h.get_value)
            else
              o[key] = h.get_value
            end
          end
        end

        def content_length
          headers['content-length'].to_i
        end

        def content_type
          http_entity&.content_type || headers['content-type']
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

        attr_reader :response, :http_entity

        def detect_encoding_from_content_charset
          return unless http_entity.content_type

          content_type = ContentType.parse(http_entity.content_type)
          charset = content_type.charset&.to_string
          return unless charset

          begin
            Encoding.find(charset)
          rescue ArgumentError
            nil
          end
        end

        # Returns a byte buffer to be used for reading the response
        def create_response_buffer(max_response_size)
          content_length = http_entity.content_length
          buffer_capacity = content_length.negative? ? DEFAULT_BUFFER_SIZE : [content_length, max_response_size].min
          ByteArrayBuffer.new(buffer_capacity)
        end

        # Load data from the input http entity into a byte buffer, controlling for response size limits
        def consume_http_entity(max_response_size:, request_timeout:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          stream = http_entity.content

          # Make sure we understand the encoding used by the server
          check_content_encoding

          # The buffer for holding the whole response
          response_buffer = create_response_buffer(max_response_size)

          # A single chunk to be read from the response at a time
          chunk = Java::byte[1024].new

          # Consume the stream in chunks while checking response size limits and timeouts
          loop do
            received_bytes = stream.read(chunk)
            break if received_bytes.negative? # -1 indicates end of stream

            total_downloaded = response_buffer.length + received_bytes
            if max_response_size && total_downloaded >= max_response_size
              raise Crawler::Http::ResponseTooLarge, <<~ERROR.squish
                Failed to fetch the response from #{url.inspect} after downloading
                #{total_downloaded} bytes (hit the response size limit of
                #{max_response_size})
              ERROR
            end

            response_buffer.append(chunk, 0, received_bytes)

            raise Crawler::Http::RequestTimeout, url if request_timeout && time_since_request_start > request_timeout
          end

          response_buffer.to_byte_array
        ensure
          # NOTE: In case of a timeout, this may block for a bit, so our timeout errors
          # are not raised immediately after a connection timeout has been reached.
          stream.close
        end

        # Returns the list of content encodings applied to the response
        def response_content_encodings
          content_encoding = http_entity.content_encoding.to_s
          content_encoding.downcase.split(',').map(&:strip).reject(&:blank?)
        end

        # Makes sure the content-encoding used by the server is supported by our client
        #
        # The client usually takes care of the encoding transparently for us, but
        # if an encoding is not supported, it will pass it through to us here and we
        # need to detect unsupported encoding values and raise an error instead of
        # ingesting binary garbage as content.
        def check_content_encoding
          response_content_encodings.each do |encoding|
            next if Crawler::Http::Client::Base::CONTENT_DECODERS.include?(encoding)

            raise Crawler::Http::InvalidEncoding, encoding
          end
        end
      end
    end
  end
end
