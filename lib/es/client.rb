#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'fileutils'
require 'elasticsearch'
require 'active_support/core_ext/integer/time'
require 'uri'

module ES
  class Client < ::Elasticsearch::Client
    USER_AGENT = 'elastic-web-crawler-'

    DEFAULT_RETRY_ON_FAILURE = 3 # retry count
    DEFAULT_DELAY_ON_RETRY = 2 # in seconds

    DEFAULT_REQUEST_TIMEOUT = 10 # in seconds

    FAILED_BULKS_DIR = 'output/failed_payloads'

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
        request_timeout: es_config.fetch(:request_timeout, DEFAULT_REQUEST_TIMEOUT),
        reload_on_failure: es_config.fetch(:reload_on_failure, false),
        transport_options: {
          headers: {
            'user-agent': "#{USER_AGENT}#{crawler_version}",
            'X-elastic-product-origin': 'crawler'
          }
        }
      }
      @max_retries, @retry_delay = get_retry_configuration(es_config)

      config.merge!(configure_host_port(es_config))
      config.merge!(configure_auth(es_config))
      config.deep_merge!(configure_ssl(es_config))
      config.merge!(configure_compression(es_config))

      config
    end

    def bulk(payload = {})
      execute_with_retry(description: 'Bulk index') do
        raise_if_necessary(super(payload))
      end
    rescue StandardError => e
      store_failed_payload(payload)
      raise e
    end

    # Perform a search query with pagination and return a formatted response.
    # ES paginates search results using a combination of `sort` and `search_after`.
    # We repeat search queries until the response is empty, which is how we know pagination is complete.
    def paginated_search(index_name, query)
      results = []

      loop do
        response = execute_with_retry(description: 'Search') do
          search(index: [index_name], body: query)
        end
        hits = response['hits']['hits']
        return results if hits.empty?

        results.push(*hits)
        query['search_after'] = hits.last['sort']
      end
    end

    def delete_by_query(index:, body:, refresh: true)
      execute_with_retry(description: 'Delete by query') do
        super(index:, body:, refresh:)
      end
    end

    private

    def configure_host_port(es_config)
      host = es_config[:host]
      port = es_config[:port]

      uri = URI.parse(host)
      scheme = uri.scheme
      host = uri.host || host

      # Port from separate argument takes precedence over port in hostname
      port ||= uri.port

      {
        scheme: scheme,
        host: host,
        port: port
      }.compact
    end

    def get_retry_configuration(es_config)
      retry_count = es_config.fetch(:retry_on_failure, DEFAULT_RETRY_ON_FAILURE)

      # Handle alternative retry count values
      if retry_count == false
        retry_count = 0
      elsif retry_count == true || !retry_count.is_a?(Integer) || retry_count.negative?
        retry_count = DEFAULT_RETRY_ON_FAILURE
      end

      delay_on_retry = es_config.fetch(:delay_on_retry, DEFAULT_DELAY_ON_RETRY)

      delay_on_retry = DEFAULT_DELAY_ON_RETRY unless delay_on_retry.is_a?(Integer) && delay_on_retry.positive?

      @system_logger.debug(
        "Elasticsearch client retry configuration: #{retry_count} retries with #{delay_on_retry}s delay"
      )

      [retry_count, delay_on_retry]
    end

    def configure_auth(es_config)
      if es_config[:api_key]
        @system_logger.info('ES connections will be authorized with configured API key')
        { api_key: es_config[:api_key] }
      elsif es_config[:username] || es_config[:password]
        @system_logger.info('ES connections will use configured username/password')
        { user: es_config[:username], password: es_config[:password] }
      else
        @system_logger.info('ES connections will use no authentication')
        {}
      end
    end

    def configure_ssl(es_config)
      # See: https://www.rubydoc.info/gems/faraday/Faraday/SSLOptions
      ssl_config = {
        ca_fingerprint: es_config[:ca_fingerprint],
        transport_options: {}
      }.compact

      if es_config[:ssl_verify] == false
        if es_config[:ca_path] || es_config[:ca_file] || es_config[:verify_hostname]
          @system_logger.warn(
            'SSL verification is disabled, but SSL verification options are configured. These options will be ignored.'
          )
        end

        ssl_config[:transport_options][:ssl] = { verify: false }
      else
        # SSL Verification is enabled (or default)
        ssl_config[:transport_options][:ssl] = {
          ca_file: es_config[:ca_file],
          ca_path: es_config[:ca_path],
          verify: es_config[:ssl_verify]
        }.compact
      end

      @system_logger.debug("ES connection SSL config: #{ssl_config}")

      ssl_config
    end

    def configure_compression(es_config)
      compress = es_config[:compression] != false
      @system_logger.debug("ES connection compression is #{compress ? 'enabled' : 'disabled'}")
      { compression: compress }
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

    def execute_with_retry(description:) # rubocop:disable Metrics/MethodLength
      try = 0
      max_tries = 1 + @max_retries
      begin
        yield
      rescue StandardError => e
        try += 1
        if try < max_tries
          wait_time = @retry_delay**try
          @system_logger.warn(
            "#{description} attempt #{try}/#{max_tries} failed: '#{e.message}'. Retrying in #{wait_time.to_f}s.."
          )
          sleep(wait_time)
          retry
        else
          log_final_failure(description:, tries: try, error: e)
          raise e
        end
      end
    end

    def log_final_failure(description:, tries:, error:)
      if @max_retries.nonzero?
        @system_logger.error("#{description} failed after #{tries} attempts: '#{error.message}'.")
      else
        @system_logger.error("#{description} failed: '#{error.message}'. Retries disabled.")
      end
    end
  end
end
