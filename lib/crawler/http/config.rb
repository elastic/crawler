#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, '..', 'api', 'config')

module Crawler
  module Http
    class Config < SimpleDelegator
      DEFAULT_MAX_POOL_SIZE = 50
      DEFAULT_CONNECTION_REQUEST_TIMEOUT = 60
      DEFAULT_CHECK_CONNECTION_TIMEOUT = 2

      ALLOWED_OPTIONS = %i[
        check_connection_timeout
        connection_request_timeout
        connect_timeout
        compression_enabled
        max_pool_size
        pool_max
        pool_max_per_route
        request_timeout
        socket_timeout
        user_agent
        ssl_ca_certificates
        ssl_verification_mode
        http_proxy_host
        http_proxy_port
        http_proxy_scheme
        http_proxy_username
        http_proxy_password
      ].freeze

      REQUIRED_OPTIONS = %i[
        loopback_allowed
        private_networks_allowed
        logger
      ].freeze

      ALL_OPTIONS = (ALLOWED_OPTIONS + REQUIRED_OPTIONS).freeze

      def initialize(config)
        if (unsupported_options = config.keys - ALL_OPTIONS) && unsupported_options.any?
          raise ArgumentError, "#{unsupported_options.first} is not a supported option"
        end

        validate_required_options(config, REQUIRED_OPTIONS)
        super
      end

      def http_proxy_host
        fetch(:http_proxy_host, nil)
      end

      def http_proxy_port
        fetch(:http_proxy_port, crawler_default(:http_proxy_port)).to_i
      end

      def http_proxy_username
        fetch(:http_proxy_username, nil)
      end

      def http_proxy_password
        fetch(:http_proxy_password, nil)
      end

      def http_proxy_scheme
        fetch(:http_proxy_scheme, crawler_default(:http_proxy_protocol))
      end

      def ssl_ca_certificates
        fetch(:ssl_ca_certificates, [])
      end

      def ssl_verification_mode
        fetch(:ssl_verification_mode, crawler_default(:ssl_verification_mode))
      end

      def user_agent
        fetch(:user_agent, crawler_default(:user_agent))
      end

      def loopback_allowed?
        fetch(:loopback_allowed, false)
      end

      def private_networks_allowed?
        fetch(:private_networks_allowed, false)
      end

      def max_pool_size
        fetch(:pool_max, DEFAULT_MAX_POOL_SIZE)
      end

      def pool_max_per_route
        fetch(:pool_max_per_route, max_pool_size)
      end

      def socket_timeout
        fetch(:socket_timeout, crawler_default(:socket_timeout))
      end

      def connection_request_timeout
        fetch(:connection_request_timeout, DEFAULT_CONNECTION_REQUEST_TIMEOUT)
      end

      def connect_timeout
        fetch(:connect_timeout, crawler_default(:connect_timeout))
      end

      def check_connection_timeout
        fetch(:check_connection_timeout, DEFAULT_CHECK_CONNECTION_TIMEOUT)
      end

      def compression_enabled
        fetch(:compression_enabled, true)
      end

      private

      def crawler_default(setting)
        Crawler::API::Config::DEFAULTS.fetch(setting)
      end

      def validate_required_options(options, required_keys)
        required_keys.each do |key|
          raise ArgumentError, "#{key} is a required option" unless options.key?(key)
        end
      end
    end
  end
end
