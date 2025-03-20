#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, '..', '..', 'errors')

# base class for all log handlers
module Crawler
  module LogHandler
    class Base
      def initialize(log_level)
        puts 'INITIALIZING LOG HANDLER'
      end

      def debug
        raise NotImplementedError
      end

      def info
        raise NotImplementedError
      end

      def warn
        raise NotImplementedError
      end

      def error
        raise NotImplementedError
      end

      def fatal
        raise NotImplementedError
      end

      def event
        raise NotImplementedError
      end

      def close
        raise NotImplementedError
      end
    end
  end
end
