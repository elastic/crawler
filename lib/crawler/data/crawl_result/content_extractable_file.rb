#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'digest'

require_dependency(File.join(__dir__, 'success'))

module Crawler
  module Data
    module CrawlResult
      class ContentExtractableFile < Success
        # Allow constructor to be called on concrete result classes
        public_class_method :new

        def content_hash
          @content_hash ||= Digest::SHA1.hexdigest(content)
        end

        def base64_encoded_content
          Base64.strict_encode64(content)
        end
      end
    end
  end
end
