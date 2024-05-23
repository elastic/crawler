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
        config = load_yaml(crawl_config)
        unless es_config.nil?
          es_config = load_yaml(es_config)
          config.merge!(es_config) unless es_config.empty?
        end

        Crawler::API::Config.new(**config.deep_symbolize_keys)
      end
    end
  end
end
