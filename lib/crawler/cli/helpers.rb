#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module CLI
    module Helpers
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

      # rubocop:disable Style/SafeNavigation
      def self.load_crawl_config(crawl_config, es_config)
        config = load_yaml(crawl_config)
        unless es_config.nil?
          es_config = load_yaml(es_config)
          # deep merge config into es_config to make sure fields in crawler config
          # are prioritized
          es_config.deep_merge!(config) unless es_config.nil?
        end

        # nest any flat yaml present in the configs
        nested_config = nest_configs(config)

        Crawler::API::Config.new(**nested_config.deep_symbolize_keys)
      end
      # rubocop:enable Style/SafeNavigation

      def self.nest_configs(es_config)
        nested_config = {}
        es_config.each do |key, value|
          all_fields = key.split('.')
          last_key = all_fields[-1]

          pointer = nested_config
          all_fields[..-2].each do |field|
            pointer[field] = {} unless pointer.key?(field)
            pointer = pointer[field]
          end
          pointer[last_key] = value
        end
        nested_config
      end
    end
  end
end
