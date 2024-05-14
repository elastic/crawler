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
    class Crawl < Dry::CLI::Command
      desc 'Run a crawl of the site'

      argument :crawl_config, required: true, desc: 'Path to crawl config file'

      option :es_config, desc: 'Path to elasticsearch config file'
      option :debug, type: :boolean, default: false, desc: 'Enable verbose mode'

      def call(crawl_config:, debug:, es_config: nil, **)
        config = load_yaml(crawl_config)
        unless es_config.nil?
          es_config = load_yaml(es_config)
          config.merge!(es_config) unless es_config.empty?
        end

        crawl_config = Crawler::API::Config.new(**config.deep_symbolize_keys)
        crawl = Crawler::API::Crawl.new(crawl_config)

        crawl.start!
      end

      private

      def die(message, print_help = false)
        puts "ERROR: #{message}"
        if print_help
          puts
          print_usage_help
        end

        exit(1)
      end

      #---------------------------------------------------------------------------------------------------
      def load_yaml(file_path)
        die("Config file #{file_path} does not exist!") unless File.readable?(file_path)
        begin
          YAML.load_file(file_path)
        rescue StandardError => e
          die("Failed to load config file #{file_path}: #{e}")
        end
      end
    end
  end
end
