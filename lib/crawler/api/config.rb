#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'active_support/core_ext/numeric/bytes'

require_dependency(File.join(__dir__, '..', '..', 'statically_tagged_logger'))
require_dependency(File.join(__dir__, '..', 'data', 'crawl_result', 'html'))
require_dependency(File.join(__dir__, '..', 'data', 'extraction', 'ruleset'))
require_dependency(File.join(__dir__, '..', 'document_mapper'))
require_dependency(File.join(__dir__, '..', 'utils'))

java_import java.io.ByteArrayInputStream
java_import java.security.cert.CertificateFactory
java_import java.security.cert.X509Certificate

# A crawl config contains all the necessary parameters to start an individual crawl, e.g. the
# domain(s) and seed url(s), where to output the extracted content, etc.
#
module Crawler
  module API
    class Config # rubocop:disable Metrics/ClassLength
      LOG_LEVELS = {
        debug: Logger::DEBUG,
        info: Logger::INFO,
        warn: Logger::WARN,
        error: Logger::ERROR,
        fatal: Logger::FATAL
      }.stringify_keys.freeze

      CONFIG_FIELDS = [
        :log_level,            # Log level set in config file, defaults to `info`
        :event_logs,           # Whether event logs are output to the shell, defaults to `false`

        :crawl_id,             # Unique identifier of the crawl (used in logs, etc)
        :crawl_stage,          # Stage name for multi-stage crawls

        :domains,              # Array of domains
        :domain_allowlist,     # Array of domain names for restricting which links to follow
        :seed_urls,            # An array or an enumerator of initial URLs to crawl
        :sitemap_urls,         # Array of sitemap URLs to be used for content discovery
        :crawl_rules,          # Array of allow/deny-listed URL patterns
        :extraction_rules,     # Contains domains extraction rules
        :schedule,             # For scheduled jobs; not used outside of CLI

        :robots_txt_service,   # Service to fetch robots.txt
        :output_sink,          # The type of output, either :console | :file | :elasticsearch
        :output_dir,           # If writing to the filesystem, the directory to write to
        :output_index,         # If writing to Elasticsearch, the index to write to
        :results_collection,   # An Enumerable collection for storing mock crawl results
        :user_agent,           # The User-Agent used for requests made from the crawler.
        :stats_dump_interval,  # How often should we output stats in the logs during a crawl
        :purge_crawl_enabled,  # Whether or not to purge ES docs after a crawl, only possible for elasticsearch sinks
        :full_html_extraction_enabled, # Whether or not to include the full HTML in the crawl result JSON

        # Elasticsearch settings
        :elasticsearch, # Elasticsearch connection settings

        # HTTP header settings
        :http_header_service,  # Service to determine the HTTP headers used for requests made from the crawler.
        :http_auth_allowed,    # If HTTP auth is permitted for non-HTTPS URLs.
        :auth,                 # HTTP auth settings.

        # DNS security settings
        :loopback_allowed,         # If loopback is permitted during DNS resolution
        :private_networks_allowed, # If private network IPs are permitted during DNS resolution

        # SSL security settings
        :ssl_ca_certificates,   # An array of custom CA certificates to trust
        :ssl_verification_mode, # SSL verification mode to use for all connections

        # HTTP proxy settings,
        :http_proxy_host,       # Proxy host to use for all requests (default: no proxying)
        :http_proxy_port,       # Proxy port to use for all requests (default: 8080)
        :http_proxy_protocol,   # Proxy host scheme: http (default) or https
        :http_proxy_username,   # Proxy auth user (default: no auth)
        :http_proxy_password,   # Proxy auth password (default: no auth)

        # The type of URL queue to be used
        :url_queue,
        # The max number of in-flight URLs we can hold. Specific semantics of this depend on the queue implementation
        :url_queue_size_limit,

        # Crawl-level limits
        :max_duration,         # Maximum duration of a single crawl, in seconds
        :max_crawl_depth,      # Maximum depth to follow links. Seed urls have depth 1.
        :max_unique_url_count, # Maximum number of unique URLs we process before stopping.
        :max_url_length,       # URL length limit
        :max_url_segments,     # URL complexity limit
        :max_url_params,       # URL parameters limit
        :threads_per_crawl,    # Number of threads to use for a single crawl.

        # Request-level limits
        :max_redirects,        # Maximum number of redirects before raising an error
        :max_response_size,    # Maximum HTTP response length before raising an error
        :connect_timeout,      # Timeout for establishing connections.
        :socket_timeout,       # Timeout for open connections.
        :request_timeout,      # Timeout for requests.

        # Extraction limits
        :max_title_size,         # HTML title length limit in bytes
        :max_body_size,          # HTML body length limit in bytes
        :max_keywords_size,      # HTML meta keywords length limit in bytes
        :max_description_size,   # HTML meta description length limit in bytes

        :max_extracted_links_count, # Number of links to extract for crawling
        :max_indexed_links_count,   # Number of links to extract for indexing
        :max_headings_count,        # HTML heading tags count limit

        # Binary content extraction (from files)
        :binary_content_extraction_enabled,    # Enable content extraction of non-HTML files found during a crawl
        :binary_content_extraction_mime_types, # Extract files with the following MIME types

        # Other crawler tuning settings
        :default_encoding,            # Default encoding used for responses that do not specify a charset
        :compression_enabled,         # Enable/disable HTTP content compression
        :sitemap_discovery_disabled,  # Enable/disable crawling of sitemaps defined in robots.txt
        :head_requests_enabled        # Fetching HEAD requests before GET requests enabled

      ].freeze

      EXTRACTION_RULES_FIELDS = %i[url_filters rules].freeze

      # Please note: These defaults are used the `Crawler::HttpUtils::Config` class.
      # Make sure to check those before renaming or removing any defaults.
      DEFAULTS = {
        log_level: 'info',
        event_logs: false,

        crawl_stage: :primary,

        sitemap_urls: [],
        user_agent: "Elastic-Crawler (#{Crawler.version})",
        stats_dump_interval: 10.seconds,

        max_duration: 24.hours,
        max_crawl_depth: 10,
        max_unique_url_count: 100_000,

        max_url_length: 2048,
        max_url_segments: 16,
        max_url_params: 32,

        max_redirects: 10,
        max_response_size: 10.megabytes,

        ssl_ca_certificates: [],
        ssl_verification_mode: 'full',

        http_proxy_port: 8080,
        http_proxy_protocol: 'http',

        connect_timeout: 10,
        socket_timeout: 10,
        request_timeout: 60,

        max_title_size: 1.kilobyte,
        max_body_size: 5.megabytes,
        max_keywords_size: 512.bytes,
        max_description_size: 1.kilobyte,

        max_extracted_links_count: 1000,
        max_indexed_links_count: 25,
        max_headings_count: 25,

        binary_content_extraction_enabled: false,
        binary_content_extraction_mime_types: [],

        output_sink: :elasticsearch,
        url_queue: :memory_only,
        threads_per_crawl: 10,

        default_encoding: 'UTF-8',
        compression_enabled: true,
        sitemap_discovery_disabled: false,
        head_requests_enabled: false,

        extraction_rules: {},
        crawl_rules: {},
        purge_crawl_enabled: true,
        full_html_extraction_enabled: false
      }.freeze

      # Settings we are not allowed to log due to their sensitive nature
      SENSITIVE_FIELDS = %i[
        auth
        http_header_service
        http_proxy_username
        http_proxy_password
        elasticsearch
      ].freeze

      # Specific processed configuration options
      attr_reader(*CONFIG_FIELDS)

      # Loggers available within the crawler
      attr_reader :system_logger # for free-text logging
      attr_reader :event_logger  # for structured logs

      def initialize(params = {})
        params = DEFAULTS.merge(params.symbolize_keys)

        # Make sure we don't have any unexpected parameters
        validate_param_names!(params)

        # Assign instance variables based on the values passed into the constructor
        # Please note: we assign all parameters as-is and then validate specific params below
        assign_config_params(params)

        # Configure crawl ID and stage name
        configure_crawl_id!

        # Setup logging for free-text and structured events
        configure_logging!(params[:log_level], params[:event_logs])

        # Normalize and validate parameters
        confugure_ssl_ca_certificates!
        configure_domain_allowlist!
        configure_crawl_rules!
        configure_seed_urls!
        configure_robots_txt_service!
        configure_http_header_service!
        configure_sitemap_urls!
        configure_extraction_rules!
      end

      def to_s
        formatted_fields = CONFIG_FIELDS.map do |k|
          value = SENSITIVE_FIELDS.include?(k) ? '[redacted]' : public_send(k)
          "#{k}=#{value}"
        end
        "<#{self.class}: #{formatted_fields.join('; ')}>"
      end

      def validate_param_names!(params)
        extra_params = params.keys - CONFIG_FIELDS
        raise ArgumentError, "Unexpected configuration options: #{extra_params.inspect}" if extra_params.any?
      end

      def assign_config_params(params)
        params.each do |k, v|
          instance_variable_set("@#{k}", v.dup)
        end
      end

      # Generate a new crawl id if needed
      def configure_crawl_id!
        @crawl_id ||= BSON::ObjectId.new.to_s # rubocop:disable Naming/MemoizedInstanceVariableName
      end

      def confugure_ssl_ca_certificates!
        ssl_ca_certificates.map! do |cert|
          if /BEGIN CERTIFICATE/.match?(cert)
            parse_certificate_string(cert)
          else
            load_certificate_from_file(cert)
          end
        end
      end

      # Parses a PEM-formatted certificate and returns an X509Certificate object for it
      def parse_certificate_string(pem)
        cert_stream = ByteArrayInputStream.new(pem.to_java_bytes)
        cert = CertificateFactory.getInstance('X509').generateCertificate(cert_stream)
        cert.to_java(X509Certificate)
      rescue Java::JavaSecurity::GeneralSecurityException => e
        raise ArgumentError, "Error while parsing an SSL certificate: #{e}"
      end

      # Loads an SSL certificate from disk and returns it as an X509Certificate object
      def load_certificate_from_file(file_name)
        system_logger.debug("Loading SSL certificate: #{file_name.inspect}")
        cert_content = File.read(file_name)
        parse_certificate_string(cert_content)
      rescue SystemCallError => e
        raise ArgumentError, "Error while loading an SSL certificate #{file_name.inspect}: #{e}"
      end

      def configure_domain_allowlist!
        raise ArgumentError, 'Needs at least one domain' unless domains&.any?

        @domain_allowlist, urls = domains.each_with_object([[], []]) do |domain, (allowlist, urls)|
          raise ArgumentError, 'Each domain requires a url' unless domain[:url]

          validate_domain!(domain[:url])
          allowlist << Crawler::Data::Domain.new(domain[:url])
          urls << domain[:url]
        end

        raise ArgumentError, "Main domain urls must be unique, but found [#{urls.join(', ')}]" unless urls == urls.uniq
      end

      def validate_domain!(domain)
        url = URI.parse(domain)
        raise ArgumentError, "Domain #{domain.inspect} does not have a URL scheme" unless url.scheme
        raise ArgumentError, "Domain #{domain.inspect} is not an HTTP(S) site" unless url.is_a?(URI::HTTP)
        raise ArgumentError, "Domain #{domain.inspect} cannot have a path" unless url.path == ''
      end

      def configure_crawl_rules!
        @crawl_rules = domains.each_with_object({}) do |domain, crawl_rules|
          url = domain[:url]
          if domain[:crawl_rules].nil?
            crawl_rules[url] = {}
            next
          end

          raise ArgumentError, "Crawl rules for #{url} is not an array" unless domain[:crawl_rules].is_a?(Array)

          crawl_rules[url] = build_crawl_rules(domain[:crawl_rules], url)
        end
      end

      def build_crawl_rules(crawl_rules, url)
        crawl_rules.map do |crawl_rule|
          policy = crawl_rule[:policy].to_sym
          url_pattern = Regexp.new(
            Crawler::Utils.url_pattern(url, crawl_rule[:type], crawl_rule[:pattern])
          )
          Crawler::Data::Rule.new(policy, url_pattern:)
        end
      end

      def configure_seed_urls!
        # use the main url if no seed_urls were configured
        seed_urls = domains.flat_map do |domain|
          if domain[:seed_urls]&.any?
            domain[:seed_urls]
          else
            ["#{domain[:url]}/"]
          end
        end

        # Convert seed URLs into an enumerator if needed
        @seed_urls = seed_urls.each unless seed_urls.is_a?(Enumerator)

        # Parse and validate all URLs as we access them
        @seed_urls = seed_urls.lazy.map do |seed_url|
          Crawler::Data::URL.parse(seed_url).tap do |url|
            raise ArgumentError, "Unsupported scheme for a seed URL: #{url}" unless url.supported_scheme?
          end
        end
      end

      def configure_robots_txt_service!
        @robots_txt_service ||= Crawler::RobotsTxtService.new(user_agent:) # rubocop:disable Naming/MemoizedInstanceVariableName
      end

      def configure_http_header_service!
        @http_header_service ||= Crawler::HttpHeaderService.new(auth:) # rubocop:disable Naming/MemoizedInstanceVariableName
      end

      def configure_sitemap_urls!
        # Parse and validate all URLs
        @sitemap_urls = @domains.filter_map do |domain|
          domain[:sitemap_urls] if domain[:sitemap_urls]&.any?
        end.flatten

        @sitemap_urls.map! do |sitemap_url|
          Crawler::Data::URL.parse(sitemap_url).tap do |url|
            raise ArgumentError, "Unsupported scheme for a sitemap URL: #{url}" unless url.supported_scheme?
          end
        end
      end

      def configure_extraction_rules!
        @extraction_rules = @domains.each_with_object({}) do |domain, extraction_rules|
          url = domain[:url]
          rulesets = domain[:extraction_rulesets].nil? ? [] : domain[:extraction_rulesets]

          raise ArgumentError, "Extraction rulesets for #{url} is not an array" unless rulesets.is_a?(Array)

          extra_rules = rulesets.flat_map(&:keys) - EXTRACTION_RULES_FIELDS
          if extra_rules.any?
            raise ArgumentError,
                  "Unexpected extraction ruleset(s) for #{url}: #{extra_rules.join(', ')}"
          end

          extraction_rules[url] = rulesets.map { |ruleset| Crawler::Data::Extraction::Ruleset.new(ruleset, url) }
        end
      end

      def configure_logging!(log_level, event_logs_enabled)
        @event_logger = Logger.new($stdout) if event_logs_enabled

        system_logger = Logger.new($stdout)
        system_logger.level = LOG_LEVELS[log_level]

        # Add crawl id and stage to all logging events produced by this crawl
        tagged_system_logger = StaticallyTaggedLogger.new(system_logger)
        @system_logger = tagged_system_logger.tagged("crawl:#{crawl_id}", crawl_stage)
      end

      # Returns an event generator used to capture crawl life cycle events
      def events
        @events ||= Crawler::EventGenerator.new(self)
      end

      # Returns the per-crawl stats object used for aggregating crawl statistics
      def stats
        @stats ||= Crawler::Stats.new
      end

      def document_mapper
        @document_mapper ||= ::Crawler::DocumentMapper.new(self)
      end

      # Receives a crawler event object and outputs it into relevant systems
      def output_event(event)
        # Log the event
        event_logger << "#{event.to_json}\n" if event_logger

        # Count stats for the crawl
        stats.update_from_event(event)
      end
    end
  end
end
