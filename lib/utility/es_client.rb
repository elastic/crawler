#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'elasticsearch'

module Utility
  class EsClient < ::Elasticsearch::Client
    USER_AGENT = 'elastic-web-crawler-'

    class IndexingFailedError < StandardError
      def initialize(message, error = nil)
        super(message)
        @cause = error
      end

      attr_reader :cause
    end

    def initialize(es_config, system_logger, crawler_version, &block)
      @system_logger = system_logger
      super(connection_configs(es_config, crawler_version), &block)
    end

    def connection_configs(es_config, crawler_version) # rubocop:disable Metrics/MethodLength
      configs = {
        transport_options: {
          headers: {
            'user-agent': "#{USER_AGENT}#{crawler_version}",
            'X-elastic-product-origin': 'crawler'
          }
        }
      }

      if es_config[:api_key]
        configs[:host] = es_config[:host]
        configs[:api_key] = es_config[:api_key]
        @system_logger.info('Initializing ES client with API key...')
      else
        # create a URL with pattern http(s)://<username>:<password>@host.com
        configs[:url] = es_config[:host].sub(%r{^https?://}) do |match|
          "#{match}#{es_config[:username]}:#{es_config[:password]}@"
        end
        @system_logger.info('Initializing ES client with username and password...')
      end

      configs
    end

    def bulk(arguments = {})
      raise_if_necessary(super(arguments))
    end

    private

    def raise_if_necessary(response) # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
      if response['errors']
        first_error = nil
        ops = %w[index delete]

        response['items'].each do |item|
          ops.each do |op|
            next unless item.key?(op) && item[op].key?('error')

            first_error = item

            break
          end
        end

        @system_logger.debug("Errors found in bulk response. Full response: #{response}")
        if first_error
          # TODO: add trace logging
          # TODO: consider logging all errors instead of just first
          raise IndexingFailedError,
                "Failed to index documents into Elasticsearch with an error '#{first_error.to_json}'."
        else
          raise IndexingFailedError,
                "Failed to index documents into Elasticsearch due to unknown error. Full response: #{response}"
        end
      else
        @system_logger.debug('No errors found in bulk response.')
      end
      response
    end
  end
end
