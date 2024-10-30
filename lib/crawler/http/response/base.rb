#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'active_support/core_ext/string/filters'

module Crawler
  module Http
    module Response
      class Base

        DEFAULT_BUFFER_SIZE = 4_096
        DEFAULT_MAX_RESPONSE_SIZE = 10_485_760 # 10 MB

        attr_reader :url, :request_start_time, :request_end_time

        def initialize(url:, request_start_time:, request_end_time:)
          raise ArgumentError, 'Need a Crawler URL object!' unless url.is_a?(Crawler::Data::URL)

          @url = url
          @request_start_time = request_start_time
          @request_end_time = request_end_time
        end
      end
    end
  end
end
