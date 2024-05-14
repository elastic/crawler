#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

# load CLI dependencies
Dir[File.join(__dir__, 'cli/**/*.rb')].each { |f| require(f) }

module Crawler
  module CLI
    extend Dry::CLI::Registry

    register 'version', Crawler::CLI::Version, aliases: ['v', '--version']
    register 'crawl', Crawler::CLI::Crawl, aliases: %w[r run]
  end
end
