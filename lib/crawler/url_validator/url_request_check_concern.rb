# frozen_string_literal: true

module Crawler
  module UrlValidator::UrlRequestCheckConcern # rubocop:disable Style/ClassAndModuleChildren
    extend ActiveSupport::Concern

    def validate_url_request # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      # Fetch home page using the standard Crawler HTTP executor
      @url_crawl_result = http_executor.run(
        Crawler::Data::CrawlTask.new(
          url:,
          type: :content,
          depth: 1
        )
      )

      # Common context for all results
      details = {
        status_code: url_crawl_result.status_code,
        content_type: url_crawl_result.content_type,
        request_time_msec: (url_crawl_result.duration * 1000).to_i
      }

      # Base our results on the HTTP response from the crawler
      status = url_crawl_result.status_code
      case status
      when 200
        validation_ok(:url_request, "Successfully fetched #{url}: HTTP #{status}.", details)

      when 204
        validation_fail(:url_request, "The Web server at #{url} returned no content (HTTP 204).", details)

      when 301, 302, 303, 307, 308
        redirect_validation_result(details)

      when 305
        validation_fail(:url_request, <<~MESSAGE, details)
          The web server at #{url} is configured to require an HTTP proxy for access (HTTP 305).
          This may mean that you're trying to index an internal (intranet) server.
          Read more at: https://www.elastic.co/guide/en/enterprise-search/current/crawler-private-network-cloud.html.
        MESSAGE

      when 401
        unauthorized_validation_result(details)

      when 403
        validation_fail(:url_request, <<~MESSAGE, details)
          The web server at #{url} denied us permission to view that page (HTTP 403).
          This website may require a user name and password.
          Read more at: https://www.elastic.co/guide/en/enterprise-search/current/crawler-managing.html#crawler-managing-authentication.
        MESSAGE

      when 404
        validation_fail(:url_request, <<~MESSAGE, details)
          The web server at #{url} says that there is no web page at that location (HTTP 404).
        MESSAGE

      when 407
        validation_fail(:url_request, <<~MESSAGE, details)
          The web server at #{url} is configured to require an HTTP proxy for access (HTTP 407).
          This may mean that you're trying to index an internal (intranet) server.
          Read more at: https://www.elastic.co/guide/en/enterprise-search/current/crawler-private-network-cloud.html.
        MESSAGE

      when 429
        validation_fail(:url_request, <<~MESSAGE, details)
          The web server at #{url} refused our connection due to request
          rate-limiting (HTTP 429).
        MESSAGE

      when 451
        validation_fail(:url_request, <<~MESSAGE, details)
          The web server at #{url} refused our connection due to legal reasons (HTTP 451).
        MESSAGE

      when 400...499
        validation_fail(:url_request, "Failed to fetch #{url}: HTTP #{status}.", details)

      when 500...598
        validation_fail(:url_request, "Transient error fetching #{url}: HTTP #{status}.", details)

      when 599
        validation_fail(:url_request, <<~MESSAGE, details)
          Unexpected error fetching #{url}: #{url_crawl_result.error}.
          #{url_crawl_result.suggestion_message}
        MESSAGE

      else
        validation_fail(:url_request, <<~MESSAGE, details)
          Unexpected HTTP status while fetching #{url}: HTTP #{status}.
        MESSAGE
      end
    end

    #-------------------------------------------------------------------------------------------------
    def redirect_validation_result(details) # rubocop:disable Metrics/AbcSize
      location = url_crawl_result.location

      # Very broken redirect response
      unless location
        return validation_fail(:url_request, <<~MESSAGE, details)
          The web server at #{url} responded with an HTTP #{status} redirect response
          that had no Location header. This type of response is not supported by the crawler.
        MESSAGE
      end

      # Include the redirection URL in validation results
      details = details.merge(location: location.to_s)

      # Intra-domain redirect, we should be able to crawl it without any issues
      if url.domain_name == location.domain_name
        return validation_ok(:url_request, <<~MESSAGE, details)
          The web server at #{url} redirected us to #{location}; we will follow this
          redirection when crawling pages, but you need to make sure the destination URL
          is allowed by the crawl rules configured for this domain.
        MESSAGE
      end

      # If we're running in a domain context, this is an inter-domain redirect that we cannot follow
      unless configuration
        return validation_fail(:url_request, <<~MESSAGE, details)
          The web server at #{url} redirected us to a different domain URL (#{location}).
          If you want to crawl this site, please use #{location.domain_name} as the domain name.
        MESSAGE
      end

      # A redirect to a different configured domain
      if crawler_api_config.domain_allowlist.include?(location.domain)
        return validation_ok(:url_request, <<~MESSAGE, details)
          The web server at #{url} redirected us to a different domain URL (#{location}).
          Since #{location.domain_name} is configured, we will follow
          this redirection when crawling pages, but you need to make sure the destination
          URL is allowed by the crawl rules configured for this domain.
        MESSAGE
      end

      # Inter-domain redirect that we cannot follow
      validation_fail(:url_request, <<~MESSAGE, details)
        The web server at #{url} redirected us to a different domain URL (#{location}).
        If you want to crawl this site, please configure #{location.domain_name}
        as one of the domains.
      MESSAGE
    end

    def unauthorized_validation_result(details)
      shared_message = "The web server at #{url} requires a user name and password for access (HTTP 401)"

      if ::SharedTogo::Crawler2.license_allows_authenticated_crawls?
        validation_warn(:url_request, <<~MESSAGE, details)
          #{shared_message};
          remember to configure auth for the associated domain.
          Read more at: https://www.elastic.co/guide/en/enterprise-search/current/crawler-managing.html#crawler-managing-authentication.
        MESSAGE
      else
        validation_fail(:url_request, <<~MESSAGE, details)
          #{shared_message}.
          #{::Crawler::AUTHENTICATED_CRAWL_LICENSE_ERROR}.
          Read more at: https://www.elastic.co/guide/en/enterprise-search/current/crawler-managing.html#crawler-managing-authentication.
        MESSAGE
      end
    end
  end
end
