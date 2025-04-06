#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'fileutils'
require 'elasticsearch'

module ES
  class Client < ::Elasticsearch::Client
    USER_AGENT = 'elastic-web-crawler-'
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_REQUEST_TIMEOUT = 10 # seconds
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

      # Resolve and store max_retries based on configuration
      retry_count = es_config.fetch(:retry_on_failure, DEFAULT_MAX_RETRIES) # Default to 3 if not present
      @max_retries = case retry_count
                     when true then 3 # Explicitly handle true as 3 retries
                     when ->(n) { n.is_a?(Integer) && n.positive? } then retry_count # Use positive integer
                     else 0 # Default to 0 retries for false or invalid values
                     end

      @system_logger.debug("Elasticsearch client configured with max_retries: #{@max_retries}")

      super(connection_config(es_config, crawler_version), &)
    end

    def connection_config(es_config, crawler_version)
      config = {
        request_timeout: es_config.fetch(:request_timeout, DEFAULT_REQUEST_TIMEOUT),
        reload_on_failure: es_config.fetch(:reload_on_failure, false),
        transport_options: {
          headers: {
            'user-agent': "#{USER_AGENT}#{crawler_version}",
            'X-elastic-product-origin': 'crawler'
          },
          request: {
            # Ensure timeout is consistent with the top-level setting
            timeout: es_config.fetch(:request_timeout, DEFAULT_REQUEST_TIMEOUT)
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
        raise_if_necessary(super)
      rescue StandardError => e
        retries += 1
        if @max_retries.positive? && retries <= @max_retries
          wait_time = 2**retries
          @system_logger.info(<<~LOG.squish)
            Bulk index attempt #{retries} failed: '#{e.message}'. Retrying in #{wait_time}s (try #{retries} / #{@max_retries})
          LOG
          sleep(wait_time.seconds) && retry
        else
          log_message = if @max_retries.positive?
                          "Bulk index failed after #{retries} attempts: '#{e.message}'. Writing payload to file..."
                        else
                          "Bulk index failed: '#{e.message}'. Retries disabled. Writing payload to file..."
                        end
          @system_logger.warn(log_message)
          store_failed_payload(payload)
          raise e
        end
      end
    end

    # Perform a search query with pagination and return a formatted response.
    # ES paginates search results using a combination of `sort` and `search_after`.
    # We repeat search queries until the response is empty, which is how we know pagination is complete.
    def paginated_search(index_name, query) # rubocop:disable Metrics/MethodLength
      results = []

      loop do
        retries = 0
        begin
          response = search(index: [index_name], body: query)
          hits = response['hits']['hits']
          # If hits is empty, no need to format results or continue pagination
          return results if hits.empty?

          results.push(*hits)
          # Set `search_after` param for next paginated search call using the last hit's `sort` value
          query['search_after'] = hits.last['sort']
        rescue StandardError => e
          retries += 1
          if @max_retries.positive? && retries <= @max_retries # Use instance variable and check.positive? > 0
            wait_time = 2**retries
            @system_logger.debug("Search attempt #{retries} failed: '#{e.message}'. Retrying in #{wait_time}s (try #{retries} / #{@max_retries})")
            sleep(wait_time.seconds) && retry
          else
            log_message = if @max_retries.positive?
                            "Search failed after #{retries} attempts: '#{e.message}'."
                          else
                            "Search failed: '#{e.message}'. Retries disabled."
                          end
            @system_logger.warn(log_message)
            raise e
          end
        end
      end
    end

    def delete_by_query(index:, body:, refresh: true)
      loop do
        retries = 0
        begin
          return super(index:, body:, refresh:)
        rescue StandardError => e
          retries += 1
          if @max_retries.positive? && retries <= @max_retries # Use instance variable and check > 0
            wait_time = 2**retries
            @system_logger.debug("Delete by query attempt #{retries} failed: '#{e.message}'. Retrying in #{wait_time}s (try #{retries} / #{@max_retries})")
            sleep(wait_time.seconds) && retry
          else
            log_message = if @max_retries.positive?
                            "Delete by query failed after #{retries} attempts: '#{e.message}'."
                          else
                            "Delete by query failed: '#{e.message}'. Retries disabled."
                          end
            @system_logger.warn(log_message)
            raise e
          end
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
