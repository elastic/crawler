#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'loghandlerbase')

module Crawler
  module LogHandler
    class FileHandler < LogHandler::Base
      def initialize
        super

        raise NotImplementedError
      end
    end
  end
end
