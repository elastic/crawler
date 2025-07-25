#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'fileutils'
require 'active_support/core_ext/numeric/bytes'
require 'addressable/uri'

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

        :log_file_directory,   # Path to save log files, defaults to './logs'
        :log_file_rotation_policy, # How often logs are rotated. daily | weekly | monthly, default is weekly

        :system_logs_to_file,  # Whether system logs are written to file. Default is false
        :event_logs_to_file,   # Whether event logs are written to file. Default is false

        :crawl_id,             # Unique identifier of the crawl (used in logs, etc)
        :crawl_stage,          # Stage name for multi-stage crawls

        :domains,              # Array of domains
        :domain_allowlist,     # Array of domain names for restricting which links to follow
        :seed_urls,            # An array or an enumerator of initial URLs to crawl
        :sitemap_urls,         # Array of sitemap URLs to be used for content discovery
        :crawl_rules,          # Array of allow/deny-listed URL patterns
        :extraction_rules,     # Contains domains extraction rules
        :exclude_tags,         # Contains tags (per domain) that need to be excluded from indexing
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
        :max_elastic_tag_size,   # HTML meta tag length limit in bytes
        :max_data_attribute_size, # HTML body data attribute length limit in bytes

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
        :head_requests_enabled,       # Fetching HEAD requests before GET requests enabled

        # Sink lock retry settings
        :sink_lock_retry_interval,  # Interval in seconds to retry acquiring a sink lock
        :sink_lock_max_retries      # Maximum number of retries to acquire a sink lock

      ].freeze

      EXTRACTION_RULES_FIELDS = %i[url_filters rules].freeze

      # Please note: These defaults are used the `Crawler::HttpUtils::Config` class.
      # Make sure to check those before renaming or removing any defaults.
      DEFAULTS = {
        log_level: 'info',

        log_file_directory: './logs',
        log_file_rotation_policy: 'weekly',

        system_logs_to_file: false,
        event_logs_to_file: false,

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

        private_networks_allowed: false,

        max_title_size: 1.kilobyte,
        max_body_size: 5.megabytes,
        max_keywords_size: 512.bytes,
        max_description_size: 1.kilobyte,
        max_elastic_tag_size: 512.bytes,
        max_data_attribute_size: 512.bytes,

        max_extracted_links_count: 1000,
        max_indexed_links_count: 25,
        max_headings_count: 25,

        binary_content_extraction_enabled: false,
        binary_content_extraction_mime_types: [],

        output_sink: :elasticsearch,
        output_dir: './crawled_docs',
        url_queue: :memory_only,
        threads_per_crawl: 10,

        default_encoding: 'UTF-8',
        compression_enabled: true,
        sitemap_discovery_disabled: false,
        head_requests_enabled: false,

        extraction_rules: {},
        crawl_rules: {},
        purge_crawl_enabled: true,
        full_html_extraction_enabled: false,

        # Sink lock retry settings
        sink_lock_retry_interval: 1,
        sink_lock_max_retries: 120
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
        configure_logging!(params[:log_level], params[:event_logs_to_file], params[:system_logs_to_file])

        # Normalize and validate parameters
        configure_ssl_ca_certificates!
        configure_domain_allowlist!
        configure_crawl_rules!
        configure_seed_urls!
        configure_robots_txt_service!
        configure_http_header_service!
        configure_sitemap_urls!
        configure_extraction_rules!
        configure_exclude_tags!
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

      def configure_ssl_ca_certificates!
        unless ssl_ca_certificates.is_a?(Array)
          raise ArgumentError,
                'ssl_ca_certificates must be a list of certificates or paths to certificates'
        end

        ssl_ca_certificates.map! do |cert|
          unless cert.is_a?(String)
            raise ArgumentError,
                  'each entry of ssl_ca_certificates must be a certificate or a path to a certificate'
          end

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
          normalize_domain!(domain)
          allowlist << Crawler::Data::Domain.new(domain[:url])
          urls << domain[:url]
        end

        raise ArgumentError, "Main domain urls must be unique, but found [#{urls.join(', ')}]" unless urls == urls.uniq
      end

      def validate_domain!(domain)
        url = Addressable::URI.parse(domain)
        scheme = url.scheme
        raise ArgumentError, "Domain #{domain.inspect} does not have a URL scheme" unless scheme
        raise ArgumentError, "Domain #{domain.inspect} is not an HTTP(S) site" unless %w[http https].include?(scheme)
        raise ArgumentError, "Domain #{domain.inspect} cannot have a path" unless url.path == ''
      end

      def normalize_domain!(domain)
        # Pre-emptively normalize all domain / seed URLs so we don't run into encoding issues later
        domain[:url] = normalize_url(domain[:url], remove_path: true)
        domain[:seed_urls].map! { |seed_url| normalize_url(seed_url) } if domain[:seed_urls]&.any?
        domain[:sitemap_urls].map! { |sitemap_url| normalize_url(sitemap_url) } if domain[:sitemap_urls]&.any?
      end

      def normalize_url(url, remove_path: false)
        normalized_url = Addressable::URI.parse(url).normalize
        # Remove the path from top-level domains as they aren't used for seeding
        normalized_url.path = '' if remove_path
        normalized_url_str = normalized_url.to_s

        system_logger.info("Normalized URL #{url} as #{normalized_url_str}") if url != normalized_url_str
        normalized_url_str
      end

      def validate_html5_tags(tags)
        valid_html_tags = %w[
          a abbr address area article aside audio b base bdi bdo blockquote body br button canvas caption
          cite code col colgroup data datalist dd del details dfn dialog div dl dt em embed fieldset figcaption
          figure footer form h1 h2 h3 h4 h5 h6 head header hr html i iframe img input ins kbd label legend li
          link main map mark meta meter nav noscript object ol optgroup option output p param picture pre
          progress q rp rt ruby s samp script section select small source span strong style sub summary sup
          table tbody td template textarea tfoot th thead time title tr track u ul var video wbr
        ]

        invalid = tags.reject { |tag| valid_html_tags.include?(tag) }
        raise ArgumentError, "Invalid HTML5 tags: #{invalid.join(', ')}" if invalid.any?

        true
      end

      def configure_exclude_tags!
        @exclude_tags = domains.each_with_object({}) do |domain, exclude_tags|
          url = domain[:url]
          tags = domain[:exclude_tags]

          if tags.nil?
            exclude_tags[url] = []
            next
          end

          raise ArgumentError, "Exclude tags for #{url} is not an array" unless tags.is_a?(Array)

          tags = tags.map(&:downcase)
          validate_html5_tags(tags)
          exclude_tags[url] = tags
        end
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
        @http_header_service ||= Crawler::HttpHeaderService.new(auth: all_auth_headers) # rubocop:disable Naming/MemoizedInstanceVariableName
      end

      def all_auth_headers
        all_auth_headers = []

        @domains.each do |domain|
          next unless domain[:auth]

          domain_auth_config = domain[:auth].clone # avoid modifying the original config hashmap
          domain_auth_config[:domain] = domain[:url]

          all_auth_headers.append(domain_auth_config)
        end
        all_auth_headers
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

      def configure_logging!(log_level, event_logs_to_file_enabled, system_logs_to_file_enabled)
        # set up log directory if it doesn't exist
        if event_logs_to_file_enabled || system_logs_to_file_enabled
          log_dir = log_file_directory.to_s
          FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)
        end

        # set up system logger
        @system_logger = setup_system_logger(log_level, system_logs_to_file_enabled, log_dir)
        # set up event logger
        @event_logger = setup_event_logger(log_level, event_logs_to_file_enabled, log_dir)
      end

      def setup_system_logger(log_level, system_logs_to_file_enabled, log_directory)
        system_logger = Crawler::Logging::CrawlLogger.new
        # create and add stdout handler and optional file handler
        system_logger.add_handler(
          Crawler::Logging::Handler::StdoutHandler.new(log_level)
        )
        if system_logs_to_file_enabled
          system_logger.add_handler(
            Crawler::Logging::Handler::FileHandler.new(
              log_level,
              "#{log_directory}/crawler_system.log",
              log_file_rotation_policy
            )
          )
        end
        # add tags to all handlers
        system_logger.add_tags_to_log_handlers(%W[[crawl:#{crawl_id}] [#{crawl_stage}]])
        system_logger
      end

      def setup_event_logger(log_level, event_logs_to_file_enabled, log_directory)
        event_logger = Crawler::Logging::CrawlLogger.new
        if event_logs_to_file_enabled
          event_logger.add_handler(
            Crawler::Logging::Handler::FileHandler.new(
              log_level,
              "#{log_directory}/crawler_event.log",
              log_file_rotation_policy
            )
          )
        end
        event_logger
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
    end
  end
end
