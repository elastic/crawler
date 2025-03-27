#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

# base class for all log handlers
module Crawler
  module Logging
    module Handler
      class Base
        def initialize(log_level, filename = nil, rotation_period = 'weekly')
          @log_level = log_level
          @filename = filename
          @rotation_period = rotation_period
        end

        def log
          raise NotImplementedError
        end

        def add_tags
          raise NotImplementedError
        end
      end
    end
  end
end
