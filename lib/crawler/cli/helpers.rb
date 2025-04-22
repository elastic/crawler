#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'yaml'
require 'erb'

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
          raw_content = File.read(file_path)
          erb_result = ERB.new(raw_content).result
          YAML.safe_load(erb_result, permitted_classes: [Date, Time, Symbol], aliases: true)
        rescue Psych::Exception => e
          die("YAML parsing error in config file #{file_path}: #{e}")
        rescue StandardError => e
          die("Failed to load config file #{file_path}: #{e}")
        end
      end

      def self.load_crawl_config(crawl_config, es_config)
        config = load_yaml(crawl_config)
        unless es_config.nil?
          es_config = load_yaml(es_config) || {}

          # Crawl config takes precedence over ES config
          config = es_config.deep_merge(config)

        end

        dedotted_data = dedot_hash(config)

        Crawler::API::Config.new(**dedotted_data.deep_symbolize_keys)
      end

      # Recursively nests keys in a hash based on the dot notation typical in yaml and json
      def self.dedot_hash(config)
        return {} if config.nil?
        return config unless config.is_a?(Hash)

        config.each_with_object({}) do |(key, value), nested_config|
          all_fields = key.split('.')
          last_key = all_fields.pop

          target_hash = find_or_create_target_hash(nested_config, all_fields)

          target_hash[last_key] = value.is_a?(Hash) ? dedot_hash(value) : value
        end
      end

      # Recursively finds or creates a nested hash structure based on the provided path fields.
      def self.find_or_create_target_hash(root_hash, path_fields)
        path_fields.reduce(root_hash) do |current_hash, field|
          current_hash[field] = {} unless current_hash.key?(field) && current_hash[field].is_a?(Hash)
          current_hash[field]
        end
      end
    end
  end
end
