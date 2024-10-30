#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

java_import org.htmlunit.BrowserVersion
java_import org.htmlunit.ProxyConfig
java_import org.htmlunit.SilentCssErrorHandler
java_import org.htmlunit.WebClient

require_dependency File.join(__dir__, 'base')

module Crawler
  module Http
    module Client
      class HtmlUnit < Base
        java_import org.apache.http.auth.AuthScope
        java_import org.apache.http.auth.UsernamePasswordCredentials
        java_import org.apache.http.impl.client.BasicCredentialsProvider

        def initialize(options = {})
          @config = Crawler::Http::Config.new(options)
          @logger = @config.fetch(:logger)

          @client = new_http_client
        end

        def get(url, headers: nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          raise ArgumentError, 'Need a Crawler URL object!' unless url.is_a?(Crawler::Data::URL)

          # TODO: find a way to do this
          # Check to make sure connection pool is healthy before adding more requests to it
          # check_connection_pool_stats!

          start_time = Time.now
          headers&.each do |key, value|
            @client.addRequestHeader(key, value)
          end
          response = @client.getPage(url.to_s)
          end_time = Time.now

          Crawler::Http::Response::HtmlUnit.new(
            response:,
            url:,
            request_start_time: start_time,
            request_end_time: end_time
          )
        rescue Java::JavaNet::SocketTimeoutException => e
          raise Crawler::Http::SocketTimeout, e
        rescue Java::OrgApacheHttpConn::ConnectTimeoutException => e
          raise Crawler::Http::ConnectTimeout, e
        rescue Java::JavaxNetSsl::SSLException => e
          raise Crawler::Http::SslException.for_java_error(e)
        rescue Java::OrgApacheHcCore5Http::NoHttpResponseException => e
          raise Crawler::Http::NoHttpResponseError.for_proxy_host(
            error: e,
            proxy_host: config.http_proxy_host
          )
        rescue Java::JavaLang::Exception => e
          raise Crawler::Http::BaseErrorFromJava, e
        end

        def connection_pool_stats
          # TODO: implement
          # This isn't really trackable as we only have 1 client per thread?
          raise NotImplementedError
        end

        private

        def new_http_client
          client = WebClient.new(BrowserVersion::CHROME)

          # Non-configurable settings
          client.options.throw_exception_on_script_error = false
          client.options.throw_exception_on_failing_status_code = false
          client.options.redirect_enabled = false
          client.cookie_manager.cookies_enabled = false

          # Configurable options
          # client.options.user_agent = @config.user_agent
          client.options.timeout = @config.timeout_in_milliseconds
          client.options.proxy_config = proxy_config
          client.credentials_provider = credentials_provider

          # TODO: confirm if needed:
          # connection manager (?)
          # disable compression
          # set content decoder registry

          client
        end

        def proxy_config
          ProxyConfig.new(@config.http_proxy_host, @config.http_proxy_port, @config.http_proxy_scheme)
        end

        # Returns a credentials provider to be used for all requests
        # By default, it will be empty and not have any credentials in it
        def credentials_provider
          BasicCredentialsProvider.new.tap do |provider|
            next unless @config.http_proxy_host && proxy_credentials

            logger.debug('Enabling proxy auth!')
            proxy_auth_scope = AuthScope.new(proxy_host)
            provider.set_credentials(proxy_auth_scope, proxy_credentials)
          end
        end

        # Returns HTTP credentials to be used for proxy requests
        def proxy_credentials
          return unless @config.http_proxy_username && @config.http_proxy_password

          UsernamePasswordCredentials.new(
            @config.http_proxy_username,
            @config.http_proxy_password.to_java_string.to_char_array
          )
        end
      end
    end
  end
end
