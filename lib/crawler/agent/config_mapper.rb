#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'base64'
require 'tempfile'

require 'crawler/cli/helpers'
require_dependency File.join(__dir__, '..', 'agent')
require_dependency File.join(__dir__, '..', 'api', 'config')

module Crawler
  module Agent
    # Translates the input and output units of an agent policy into crawler configuration
    module ConfigMapper
      class OutputConfigError < Error; end

      INPUT_TYPE = 'crawler'
      OUTPUT_TYPE = 'elasticsearch'

      # Keys Agent adds to every input configuration; they are not crawler settings
      POLICY_KEYS = %w[
        id type name revision use_output data_stream meta streams package policy enabled processors condition
      ].freeze

      LOG_LEVELS = { ERROR: 'error', WARN: 'warn', INFO: 'info', DEBUG: 'debug', TRACE: 'debug' }.freeze
      CONFIG_FIELDS = Crawler::API::Config::CONFIG_FIELDS.map(&:to_s).freeze

      class << self
        # Returns the keyword arguments for +Crawler::API::Config.new+
        def crawl_params(input:, output:, logger:)
          params = input_params(input.source, logger)
          params['elasticsearch'] = elasticsearch_params(output.source).merge(params['elasticsearch'] || {})
          params['output_sink'] ||= 'elasticsearch'
          params['log_level'] ||= LOG_LEVELS.fetch(input.log_level, 'info')
          if params['output_sink'].to_s == 'elasticsearch' && params['output_index'].to_s.empty?
            raise Error, 'output_index is required when writing to Elasticsearch'
          end

          params.deep_symbolize_keys
        end

        def input_params(source, logger)
          params = Crawler::CLI::Helpers.dedot_hash(source.except(*POLICY_KEYS))
          unknown = params.keys - CONFIG_FIELDS
          if unknown.any?
            logger.warn("Ignoring unsupported crawler settings from the agent policy: #{unknown.join(', ')}")
          end
          params.except(*unknown)
        end

        def elasticsearch_params(source)
          host = Array(source['hosts']).first
          raise OutputConfigError, 'Elasticsearch output has no hosts configured' if host.to_s.empty?

          {
            'host' => normalize_host(host),
            'api_key' => normalize_api_key(source['api_key']),
            'username' => presence(source['username']),
            'password' => presence(source['password'])
          }.merge(ssl_params(source['ssl'])).compact
        end

        private

        def presence(value)
          value.to_s.empty? ? nil : value
        end

        def normalize_host(host)
          host.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? host : "http://#{host}"
        end

        # Fleet hands out API keys as "id:key"; the crawler expects the base64-encoded form
        def normalize_api_key(api_key)
          return nil if api_key.to_s.empty?

          api_key.include?(':') ? Base64.strict_encode64(api_key) : api_key
        end

        def ssl_params(ssl)
          return {} unless ssl.is_a?(Hash)

          params = {}
          params['ssl_verify'] = false if ssl['verification_mode'].to_s == 'none'
          params['ca_fingerprint'] = ssl['ca_trusted_fingerprint'] unless ssl['ca_trusted_fingerprint'].to_s.empty?
          authorities = Array(ssl['certificate_authorities'])
          params['ca_file'] = ca_file(authorities) if authorities.any?
          params
        end

        # Certificate authorities can be inline PEM or paths; the ES client only takes a path
        def ca_file(authorities)
          pems = authorities.map { |ca| ca.include?('BEGIN CERTIFICATE') ? ca : File.read(ca) }
          file = Tempfile.new(['agent-elasticsearch-ca', '.pem'])
          file.write(pems.join("\n"))
          file.close
          (@ca_files ||= []) << file
          file.path
        rescue SystemCallError => e
          raise OutputConfigError, "Failed to read Elasticsearch certificate authorities: #{e.message}"
        end
      end
    end
  end
end
