#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'weakref'

require_dependency File.join(__dir__, '..', 'exceptions')
require_dependency File.join(__dir__, '..', 'config')
require_dependency File.join(__dir__, '..', 'filtering_dns_resolver')
require_dependency File.join(__dir__, '..', 'all_trusting_trust_manager')

java_import org.apache.commons.compress.compressors.brotli.BrotliCompressorInputStream

class BrotliInputStreamFactory
  java_import org.apache.hc.client5.http.entity.InputStreamFactory
  include InputStreamFactory
  include Singleton

  def create(input_stream)
    BrotliCompressorInputStream.new(input_stream)
  end
end

module Crawler
  module Http
    module Client
      class Base
        # Please note: We cannot have these java_import calls at the top level
        # because it causes conflicts with Manticore's imports of httpclient v4.5
        java_import org.apache.hc.client5.http.entity.GZIPInputStreamFactory
        java_import org.apache.hc.client5.http.entity.DeflateInputStreamFactory

        # Scoped this import to the class only to avoid conflicts with Ruby's Timeout module
        java_import org.apache.hc.core5.util.Timeout

        # The list of supported Content-Encoding methods to be used for each request
        CONTENT_DECODERS = LinkedHashMap.new.tap do |registry|
          registry.put('gzip', GZIPInputStreamFactory.instance)
          registry.put('x-gzip', GZIPInputStreamFactory.instance)
          registry.put('deflate', DeflateInputStreamFactory.instance)
          registry.put('br', BrotliInputStreamFactory.instance)
        end

        def initialize(options = {})
          @config = Crawler::Http::Config.new(options)
          @logger = @config.fetch(:logger)

          @finalizers = []
          self.class.shutdown_on_finalize(self, finalizers)

          @client = new_http_client
          finalize(client, :close)
        end

        def content_decoders
          CONTENT_DECODERS
        end

        private

        def finalize(object, args)
          finalizers << [WeakRef.new(object), Array(args)]
        end
      end
    end
  end
end
