#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'dry/cli'
require 'yaml'

module Crawler
  module CLI
    class Validate < Dry::CLI::Command
      desc 'Validate crawler configuration'

      argument :crawl_config, required: true, desc: 'Path to crawl config file'

      def call(crawl_config:, es_config: nil, **)
        crawl_config = Crawler::CLI::Helpers.load_crawl_config(crawl_config, es_config)

        crawl_config.domain_allowlist.each do |domain|
          validator = Crawler::UrlValidator.new(
            url: domain.raw_url,
            crawl_config:
          )

          print_validation_result(domain, validator)
        end
      end

      private

      def print_validation_result(domain, validator)
        if validator.valid?
          puts "Domain #{domain.raw_url} is valid"
        else
          puts "Domain #{domain.raw_url} is invalid:"
          puts validator.failed_checks.map(&:comment).join("\n")
        end
      rescue Crawler::UrlValidator::Error => e
        puts "Error validating domain #{domain.raw_url}: #{e}"
      end
    end
  end
end
