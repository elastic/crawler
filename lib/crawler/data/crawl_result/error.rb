#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency(File.join(__dir__, 'base'))

module Crawler
  module Data
    module CrawlResult
      class Error < Base
        # Fake status code to be used for unexpected internal errors
        MISCELLANEOUS_ERROR = 599

        attr_reader :error, :suggestion_message

        # INTERNAL_ERROR_STATUS is used by default for unexpected internal errors that
        # were not part of the HTTP response from a crawled web page.
        def initialize(error:, status_code: MISCELLANEOUS_ERROR, suggestion_message: nil, **kwargs)
          super(status_code:, **kwargs)
          @error = error
          @suggestion_message = suggestion_message
        end

        # Allow constructor to be called on concrete result classes
        public_class_method :new

        #---------------------------------------------------------------------------------------------
        def to_h
          super.merge(error:)
        end

        def to_s
          "<CrawlResult::Error: id=#{id}, status_code=#{status_code}, url=#{url}, error=#{error.inspect}>"
        end
      end
    end
  end
end
