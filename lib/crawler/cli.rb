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

    # Elastic Agent starts components with Beats-style `-E key=value` overrides. Only `path.data`
    # matters to the crawler; it becomes `--data-dir`, the others are dropped.
    def self.normalize_agent_arguments(arguments)
      return arguments unless arguments.first == 'agent'

      normalized = []
      pending_override = false
      arguments.each do |argument|
        if pending_override
          normalized << "--data-dir=#{argument.delete_prefix('path.data=')}" if argument.start_with?('path.data=')
          pending_override = false
        elsif argument == '-E'
          pending_override = true
        else
          normalized << argument
        end
      end
      normalized
    end

    register 'version', Crawler::CLI::Version, aliases: ['v', '--version']
    register 'crawl', Crawler::CLI::Crawl, aliases: %w[r run]
    register 'schedule', Crawler::CLI::Schedule
    register 'validate', Crawler::CLI::Validate
    register 'urltest', Crawler::CLI::UrlTest
    register 'agent', Crawler::CLI::Agent
  end
end
