#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

java_import org.htmlunit.WebClient
java_import org.htmlunit.BrowserVersion
java_import org.htmlunit.SilentCssErrorHandler

module Crawler
  module Http
    module Client
      class HtmlUnit
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
          # TODO implement
          # This isn't really trackable as we only have 1 client per thread?
          raise NotImplementedError
        end

        private

        def new_connection_manager
          raise NotImplementedError
        end

        def new_http_client
          # TODO make these configurable
          client = WebClient.new(BrowserVersion::CHROME)
          client.getOptions.setThrowExceptionOnScriptError(false)
          client.getOptions.setThrowExceptionOnFailingStatusCode(false)
          client.getOptions.setRedirectEnabled(false)
          client
        end
      end
    end
  end
end
