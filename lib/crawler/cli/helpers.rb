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

      def self.load_crawl_config(crawl_config, es_config)
        config = nest_configs(load_yaml(crawl_config))
        unless es_config.nil?
          es_config = nest_configs(load_yaml(es_config))
          # deep merge config into es_config to ensure crawler cfg takes precedence
          # then overwrite config var with result of deep merge for the Config.new() call
          config = es_config.deep_merge!(config) unless es_config.empty?
        end

        Crawler::API::Config.new(**config.deep_symbolize_keys)
      end

      def self.nest_configs(config)
        # return empty hashmap if config is nil, to catch cases where
        # a yaml is given but no content is inside
        return {} if config.nil?

        nested_config = {}
        config.each do |key, value|
          all_fields = key.split('.')
          last_key = all_fields[-1]

          pointer = nested_config
          all_fields[...-1].each do |field|
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
