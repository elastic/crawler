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
    def self.die(message)
      puts "ERROR: #{message}"
      exit(1)
    end

    def self.load_yaml(file_path)
      die("Config file #{file_path} does not exist!") unless File.readable?(file_path)
      begin
        YAML.load_file(file_path)
      rescue StandardError => e
        die("Failed to load config file #{file_path}: #{e}")
      end
    end

    def self.load_crawl_config(crawl_config, es_config)
      config = load_yaml(crawl_config)
      unless es_config.nil?
        es_config = load_yaml(es_config)
        config.merge!(es_config) unless es_config.empty?
      end

      Crawler::API::Config.new(**config.deep_symbolize_keys)
    end

    class Crawl < Dry::CLI::Command
      desc 'Run a crawl of the site'

      argument :crawl_config, required: true, desc: 'Path to crawl config file'

      option :es_config, desc: 'Path to elasticsearch config file'

      def call(crawl_config:, es_config: nil, **)
        crawl_config = Crawler::CLI.load_crawl_config(crawl_config, es_config)
        crawl = Crawler::API::Crawl.new(crawl_config)

        crawl.start!
      end
    end

    class Validate < Dry::CLI::Command
      desc 'Test a domain'

      argument :crawl_config, required: true, desc: 'Path to crawl config file'

      option :es_config, desc: 'Path to elasticsearch config file'

      def call(crawl_config:, es_config: nil, **)
        crawl_config = Crawler::CLI.load_crawl_config(crawl_config, es_config)

        crawl_config.domain_allowlist.each do |domain|
          validator = Crawler::UrlValidator.new(
            url: domain.raw_url,
            crawl_config:
          )

          if validator.valid?
            puts "Domain #{domain.raw_url} is valid"
          else
            puts "Domain #{domain.raw_url} is invalid:"
            puts validator.failed_checks.map(&:comment).join("\n")
          end
        rescue Crawler::UrlValidator::Error => e
          CLI.die(e.message)
        end
      end
    end
  end
end
