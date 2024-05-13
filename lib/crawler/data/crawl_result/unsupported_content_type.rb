#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency(File.join(__dir__, 'error'))

module Crawler
  module Data
    module CrawlResult
      class UnsupportedContentType < Error
        def initialize(content_type:, error: nil, **kwargs)
          suggestion = <<~MSG
            Check the URL content in your browser and make sure it is something
            the crawler could understand.
          MSG

          super(
            content_type:,
            error: error || "Unsupported content type: #{content_type}",
            suggestion_message: suggestion,
            **kwargs
          )
        end
      end
    end
  end
end
