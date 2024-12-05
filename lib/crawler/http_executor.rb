#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'executor')

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
module Crawler
  class HttpExecutor < Crawler::Executor # rubocop:disable Metrics/ClassLength
    class ResponseTooLarge < StandardError; end

    SUPPORTED_MIME_TYPES = {
      html: 'text/html',
      xml: %w[text/xml application/xml]
    }.freeze

    #-------------------------------------------------------------------------------------------------
    attr_reader :config, :logger

    def initialize(config) # rubocop:disable Lint/MissingSuper
      @config = config
      @logger = config.system_logger.tagged(:http)
    end

    # Returns a hash with a set of crawl-specific HTTP client metrics
    def http_client_status
      pool = http_client.connection_pool_stats
      {
        max_connections: pool.max,
        used_connections: pool.leased + pool.available
      }
    end

    #-------------------------------------------------------------------------------------------------
    # Make sure response.release_connection is called to return unused connection back to the pool
    # see more https://frameworks.readthedocs.io/en/latest/network/http/httpClientConnectionManagement.html#connection-persistence-re-use
    def run(crawl_task, follow_redirects: false) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      # rubocop:disable Metrics/BlockLength
      handling_http_errors(crawl_task) do
        loop do
          if crawl_task.http_url_with_auth? && !config.http_auth_allowed
            return Crawler::Data::CrawlResult::HttpAuthDisallowedError.new(url: crawl_task.url)
          end

          # ideally fetch HEAD first and GET later, but we fetch GET early if HEAD is unsupported
          head_response = config.head_requests_enabled ? head_request(crawl_task) : nil
          get_response = head_response.nil? || head_response.error? ? get_request(crawl_task) : nil
          response = get_response || head_response

          # Check if the redirect is too deep
          if response.redirect?
            response.release_connection

            redirect_count = crawl_task.redirect_chain.size + 1
            if redirect_count > config.max_redirects
              error = <<~LOG.squish
                Not following the HTTP redirect from #{crawl_task.url}
                to #{response.redirect_location} because the redirect chain
                is too long (#{redirect_count} pages).
              LOG
              logger.warn(error)

              return Crawler::Data::CrawlResult::RedirectError.new(
                url: crawl_task.url,
                error:
              )
            end

            # Follow redirects if needed
            if follow_redirects
              logger.info("Following the redirect from '#{crawl_task.url}' to '#{response.redirect_location}'...")
              crawl_task = Crawler::Data::CrawlTask.new(
                url: response.redirect_location,
                redirect_chain: crawl_task.redirect_chain + [crawl_task.url],
                type: crawl_task.type,
                depth: crawl_task.depth
              )
              next
            end
          end

          # Check if content-type is supported (skip step if robots.txt and redirects)
          if !crawl_task.robots_txt? && !response.redirect? && !extractable_content.include?(response.mime_type)
            response.release_connection

            return unsupported_content_type(crawl_task, response)
          end

          # fetch GET if it wasn't pre-emptively fetched earlier
          get_response = get_request(crawl_task) if get_response.nil?
          return generate_crawl_result(
            crawl_task:,
            response: get_response
          )
        end
      end
      # rubocop:enable Metrics/BlockLength
    end

    #-------------------------------------------------------------------------------------------------
    def handling_http_errors(crawl_task)
      yield
    rescue Crawler::HttpUtils::ResponseTooLarge => e
      logger.warn(e.message)
      Crawler::Data::CrawlResult::Error.new(
        url: crawl_task.url,
        error: e.message
      )
    rescue Crawler::HttpUtils::ConnectTimeout => e
      timeout_error(crawl_task:, exception: e, error: 'connection_timeout')
    rescue Crawler::HttpUtils::SocketTimeout => e
      timeout_error(crawl_task:, exception: e, error: 'read_timeout')
    rescue Crawler::HttpUtils::RequestTimeout => e
      timeout_error(crawl_task:, exception: e, error: e.message)
    rescue Crawler::HttpUtils::SslException => e
      logger.error("SSL error while performing HTTP request: #{e.message}. #{e.suggestion_message}")
      Crawler::Data::CrawlResult::Error.new(
        url: crawl_task.url,
        error: e.message,
        suggestion_message: e.suggestion_message
      )
    rescue Crawler::HttpUtils::BaseError => e
      error = "Failed HTTP request: #{e}. #{e.suggestion_message}"
      logger.error(error)
      Crawler::Data::CrawlResult::Error.new(
        url: crawl_task.url,
        error:,
        suggestion_message: e.suggestion_message
      )
    end

    #-------------------------------------------------------------------------------------------------
    # Returns an HTTP client to be used for all requests
    def http_client
      @http_client ||= Crawler::HttpClient.new(
        pool_max: 100,
        user_agent: config.user_agent,
        loopback_allowed: config.loopback_allowed,
        private_networks_allowed: config.private_networks_allowed,
        connect_timeout: config.connect_timeout,
        socket_timeout: config.socket_timeout,
        request_timeout: config.request_timeout,
        ssl_ca_certificates: config.ssl_ca_certificates,
        ssl_verification_mode: config.ssl_verification_mode,
        http_proxy_host: config.http_proxy_host,
        http_proxy_port: config.http_proxy_port,
        http_proxy_username: config.http_proxy_username,
        http_proxy_password: config.http_proxy_password,
        http_proxy_scheme: config.http_proxy_protocol,
        compression_enabled: config.compression_enabled,
        logger:
      )
    end

    private

    def head_request(crawl_task)
      http_client.head(crawl_task.url.normalized_url, headers: crawl_task.headers)
    end

    def get_request(crawl_task)
      http_client.get(crawl_task.url.normalized_url, headers: crawl_task.headers)
    end

    def unsupported_content_type(crawl_task, response)
      Crawler::Data::CrawlResult::UnsupportedContentType.new(
        url: crawl_task.url,
        status_code: response.code,
        content_type: response.content_type,
        error: "Unexpected content type #{response.content_type} for a crawl task with type=#{crawl_task.type}"
      )
    end

    #-------------------------------------------------------------------------------------------------
    def generate_crawl_result(crawl_task:, response:)
      result_args = {
        url: crawl_task.url,
        status_code: response.code,
        content_type: response['content-type'],
        start_time: response.request_start_time,
        end_time: response.request_end_time
      }

      # Special handling for redirects:
      # - we don't extract content from them
      # - we have to track the redirect chain to handle infinite redirects correctly
      if response.redirect?
        return Crawler::Data::CrawlResult::Redirect.new(
          **result_args.merge(
            location: response.redirect_location,
            redirect_chain: crawl_task.redirect_chain
          )
        )
      end

      # Special handling for error responses:
      # - No content extraction
      # - Capture the HTTP status line reason phrase as the error message
      if response.error?
        return Crawler::Data::CrawlResult::Error.new(
          **result_args.merge(error: response.reason_phrase)
        )
      end

      # Extract the body for responses that need it
      response_body = response.body(
        max_response_size: config.max_response_size,
        request_timeout: config.request_timeout,
        default_encoding: Encoding.find(config.default_encoding)
      )

      # Special responses for robots.txt tasks (no matter the content type)
      if crawl_task.robots_txt?
        return Crawler::Data::CrawlResult::RobotsTxt.new(
          **result_args.merge(content: response_body)
        )
      end

      # Everything else is handled depending on the content type
      case response.mime_type
      when *SUPPORTED_MIME_TYPES[:html]
        generate_html_crawl_result(
          crawl_task:,
          response:,
          response_body:
        )
      when *content_extractable_file_mime_types
        generate_content_extractable_file_crawl_result(
          crawl_task:,
          response:,
          response_body:
        )
      when *SUPPORTED_MIME_TYPES[:xml]
        generate_xml_sitemap_crawl_result(
          crawl_task:,
          response:,
          response_body:
        )
      else
        Crawler::Data::CrawlResult::UnsupportedContentType.new(**result_args)
      end
    ensure
      response.release_connection
    end

    #-------------------------------------------------------------------------------------------------
    def generate_unexpected_type_crawl_result(crawl_task:, response:)
      content_type = response['content-type']
      Crawler::Data::CrawlResult::UnsupportedContentType.new(
        url: crawl_task.url,
        status_code: response.code,
        content_type:,
        error: "Unexpected content type #{content_type} for a crawl task with type=#{crawl_task.type}"
      )
    end

    #-------------------------------------------------------------------------------------------------
    def timeout_error(crawl_task:, exception:, error:)
      logger.error("Failed HTTP request with a timeout: #{exception.inspect}")
      Crawler::Data::CrawlResult::Error.new(
        url: crawl_task.url,
        error:
      )
    end

    #-------------------------------------------------------------------------------------------------
    def generate_html_crawl_result(crawl_task:, response:, response_body:)
      if crawl_task.content?
        Crawler::Data::CrawlResult::HTML.new(
          url: crawl_task.url,
          status_code: response.code,
          content_type: response['content-type'],
          content: response_body,
          start_time: response.request_start_time,
          end_time: response.request_end_time
        )
      else
        generate_unexpected_type_crawl_result(
          crawl_task:,
          response:
        )
      end
    end

    #-------------------------------------------------------------------------------------------------
    def generate_xml_sitemap_crawl_result(crawl_task:, response:, response_body:)
      if crawl_task.sitemap?
        Crawler::Data::CrawlResult::Sitemap.new(
          url: crawl_task.url,
          status_code: response.code,
          content_type: response['content-type'],
          content: response_body,
          start_time: response.request_start_time,
          end_time: response.request_end_time
        )
      else
        generate_unexpected_type_crawl_result(
          crawl_task:,
          response:
        )
      end
    end

    #-------------------------------------------------------------------------------------------------
    def generate_content_extractable_file_crawl_result(crawl_task:, response:, response_body:)
      if SUPPORTED_MIME_TYPES[:xml].include?(response.mime_type) && crawl_task.sitemap?
        generate_xml_sitemap_crawl_result(crawl_task:, response:,
                                          response_body:)
      elsif crawl_task.content?
        Crawler::Data::CrawlResult::ContentExtractableFile.new(
          url: crawl_task.url,
          status_code: response.code,
          content_length: response.content_length,
          content_type: response['content-type'],
          content: response_body,
          start_time: response.request_start_time,
          end_time: response.request_end_time
        )
      else
        generate_unexpected_type_crawl_result(
          crawl_task:,
          response:
        )
      end
    end

    #-------------------------------------------------------------------------------------------------
    def content_extractable_file_mime_types
      config.binary_content_extraction_enabled ? config.binary_content_extraction_mime_types.map(&:downcase) : []
    end

    #-------------------------------------------------------------------------------------------------
    def extractable_content
      SUPPORTED_MIME_TYPES.values.flatten + content_extractable_file_mime_types
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
