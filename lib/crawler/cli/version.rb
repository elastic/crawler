#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'dry/cli'

module Crawler
  module CLI
    class Version < Dry::CLI::Command
      VERSION_PATH = File.expand_path('../../../product_version', __dir__).freeze

      desc 'Print version'

      def call(*)
        puts File.read(VERSION_PATH).strip
      end
    end
  end
end
