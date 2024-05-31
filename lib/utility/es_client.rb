#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'fileutils'
require 'elasticsearch'

module Utility
  class EsClient < ::Elasticsearch::Client
    USER_AGENT = 'elastic-web-crawler-'
    MAX_RETRIES = 3
    REQUEST_TIMEOUT = 30 # seconds
    FAILED_BULKS_DIR = 'output/failed_payloads' # directory that failed bulk payloads are output to

    class IndexingFailedError < StandardError
      def initialize(message, error = nil)
        super(message)
        @cause = error
      end

      attr_reader :cause
    end

    def initialize(es_config, system_logger, crawler_version, crawl_id, &)
      @system_logger = system_logger
      @crawl_id = crawl_id
      super(connection_config(es_config, crawler_version), &)
    end

    def connection_config(es_config, crawler_version)
      config = {
        transport_options: {
          headers: {
            'user-agent': "#{USER_AGENT}#{crawler_version}",
            'X-elastic-product-origin': 'crawler'
          },
          request: {
            timeout: REQUEST_TIMEOUT
          }
        }
      }

      config.merge!(configure_auth(es_config))
      config.deep_merge!(configure_ssl(es_config))

      config
    end

    def bulk(payload = {})
      retries = 0
      begin
        raise_if_necessary(super(payload))
      rescue StandardError => e
        retries += 1
        if retries <= MAX_RETRIES
          wait_time = 2**retries
          @system_logger.info("Bulk index attempt #{retries} failed: '#{e.message}'. Retrying in #{wait_time} seconds...")
          sleep(wait_time.seconds) && retry
        else
          @system_logger.warn("Bulk index failed after #{retries} attempts: '#{e.message}'. Writing payload to file...")
          store_failed_payload(payload)
          raise e
        end
      end
    end

    private

    def configure_auth(es_config)
      if es_config[:api_key]
        @system_logger.info('ES connections will be authorized with configured API key')
        {
          host: "#{es_config[:host]}:#{es_config[:port]}",
          api_key: es_config[:api_key]
        }
      else
        @system_logger.info('ES connections will be authorized with configured username and password')
        scheme, host = es_config[:host].split('://')
        {
          hosts: [
            {
              host:,
              port: es_config[:port],
              user: es_config[:username],
              password: es_config[:password],
              scheme:
            }
          ]
        }
      end
    end

    def configure_ssl(es_config)
      if es_config[:ca_fingerprint]
        @system_logger.info('ES connections will use SSL with ca_fingerprint')
        return {
          ca_fingerprint: es_config[:ca_fingerprint],
          transport_options: {
            ssl: { verify: false }
          }
        }
      end

      @system_logger.info('ES connections will use SSL without ca_fingerprint')
      {}
    end

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

        @system_logger.warn("Errors found in bulk response. Full response: #{response}")
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

    def store_failed_payload(payload)
      dir = "#{FAILED_BULKS_DIR}/#{@crawl_id}"
      FileUtils.mkdir_p(dir) unless File.directory?(dir)

      filename = Time.now.strftime('%Y%m%d%H%M%S')
      full_path = File.join(dir, filename)
      File.open(full_path, 'w') do |file|
        payload[:body].each do |item|
          file.puts(item)
        end
      end
      @system_logger.warn("Saved failed bulk payload to #{full_path}")
    end
  end
end
