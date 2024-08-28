#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'faux'
require_relative 'results_collection'

class FauxCrawl # rubocop:disable Metrics/ClassLength
  module Settings
    def self.faux_url
      "http://#{faux_ip}:#{faux_port}"
    end

    def self.faux_ip
      '127.0.0.1'
    end

    def self.faux_port
      9393
    end
  end

  #-------------------------------------------------------------------------------------------------
  def self.run(*args)
    new(*args).run
  end

  def self.crawl_site(&block)
    raise ArgumentError, 'Need a block defining a site' unless block

    run(Faux.site(&block))
  end

  #-------------------------------------------------------------------------------------------------
  DEFAULT_OPTIONS = {
    port: Settings.faux_port,
    seed_urls: ['/']
  }.freeze

  START_TIMEOUT = 20.seconds

  attr_reader :options, :sites, :site_containers, :timeouts, :content_extraction, :default_encoding, :crawl_id,
              :url_queue, :auth, :user_agent, :url, :seed_urls, :sitemap_urls, :domain_allowlist, :results,
              :expect_success

  delegate :crawl, to: :results

  def initialize(*sites) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    @options = sites.extract_options!
    @sites = configure_sites(*sites)

    @crawl_id = options.fetch(:crawl_id, BSON::ObjectId.new.to_s)
    @url_queue = options.fetch(:url_queue, enterprise_search? ? :esqueues_me : :memory_only)
    @user_agent = options.fetch(:user_agent, 'Faux Crawler')
    @auth = options.fetch(:auth, nil)
    @url = options.fetch(:url, Settings.faux_url)
    @seed_urls = coerce_to_absolute_urls(options[:seed_urls] || ["#{@url}/"])
    @sitemap_urls = coerce_to_absolute_urls(options[:sitemap_urls] || [])
    @domain_allowlist = seed_urls.map { |url| Crawler::Data::URL.parse(url).site }
    @content_extraction = options.fetch(:content_extraction, { enabled: false, mime_types: [] })
    @default_encoding = options[:default_encoding]
    @timeouts = options.fetch(:timeouts, {}).slice(
      :connect_timeout, :socket_timeout, :request_timeout
    ).compact
    @results = ResultsCollection.new
    @expect_success = options.fetch(:expect_success, true)

    start_sites
  end

  #-------------------------------------------------------------------------------------------------
  # Returns true if we're running within the Enterprise Search solution test suite
  def enterprise_search?
    defined?(::Crawler::LocoMoco)
  end

  #-------------------------------------------------------------------------------------------------
  def configure_sites(*sites)
    sites.collect do |(site, opts)|
      opts ||= {}
      opts.reverse_merge!(@options)
      opts.reverse_merge!(DEFAULT_OPTIONS)

      opts[:port] = opts[:port].to_s

      OpenStruct.new(opts).tap { |s| s.site = site }
    end
  end

  #-------------------------------------------------------------------------------------------------
  def start_sites # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/AbcSize
    sites_to_start = sites.uniq(&:port)
    @site_containers = sites_to_start.collect do |site|
      site_options = { port: site.port, debug: true, start: false }
      the_site = Faux::Site.new(site.site, site_options)
      Thread.new { the_site.start }
      the_site
    end

    start_time = Time.now
    ports_remaining = sites.map(&:port)

    # Wait for all sites to start or until a timeout is reached
    loop do
      break if ports_remaining.empty?

      time_elapsed = Time.now - start_time
      break if time_elapsed > START_TIMEOUT

      begin
        port_to_check = ports_remaining.first
        response = HTTPClient.new.get("http://127.0.0.1:#{port_to_check}/status")
        ports_remaining.shift if (200..299).cover?(response.status)
      rescue StandardError
        # Silence errors from health checks
      end

      sleep 0.05
    end

    return unless ports_remaining.any?

    raise "Unable to start all Faux sites; these ports never were available: #{ports_remaining.inspect}"
  end

  #-------------------------------------------------------------------------------------------------
  def stop_sites
    site_containers.each(&:stop)
  end

  #-------------------------------------------------------------------------------------------------
  def run
    # Prepare crawl configuration
    configure_crawl

    # Perform the crawl
    crawl.start!

    # Check the outcome
    raise "Test Crawl failed! Outcome: #{results.outcome_message}" if expect_success && results.outcome != :success

    results
  ensure
    stop_sites
  end

  #-------------------------------------------------------------------------------------------------
  def configure_crawl # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    # Prepare crawl config
    config = {
      crawl_id: crawl_id,
      auth: auth,
      user_agent: user_agent,
      domains: [
        {
          url: url,
          seed_urls: seed_urls,
          sitemap_urls: sitemap_urls
        }
      ],
      binary_content_extraction_enabled: content_extraction.fetch(:enabled),
      binary_content_extraction_mime_types: content_extraction.fetch(:mime_types),
      output_sink: :mock,
      results_collection: results,
      http_auth_allowed: true,
      loopback_allowed: true,
      private_networks_allowed: true,
      url_queue: url_queue
    }
    config.merge!(timeouts)
    config[:default_encoding] = default_encoding if default_encoding

    # Add crawl rules for Enterprise Search tests
    if enterprise_search?
      # Allow all traffic
      config[:crawl_rules] = domain_allowlist.map do |domain|
        {
          policy: 'allow',
          url_pattern: "\\A#{Regexp.escape(domain)}"
        }
      end

      # Use default dedup settings
      config[:deduplication_settings] = domain_allowlist.map do |domain|
        {
          fields: SharedTogo::Crawler.default_deduplication_fields,
          url_pattern: "\\A#{Regexp.escape(domain)}"
        }
      end
    end

    # When running within the solution test suite, use the solution API
    crawler_module = enterprise_search? ? ::Crawler::LocoMoco : ::Crawler

    # Setup the crawler
    results.crawl_config = crawler_module::API::Config.new(config)
    results.crawl = crawler_module::API::Crawl.new(results.crawl_config)
  end

  #-------------------------------------------------------------------------------------------------
  def coerce_to_absolute_urls(links)
    links.map do |link|
      if /^http/.match?(link)
        base_url = ::Crawler::Data::URL.parse(Settings.faux_url)
        base_url.join(link).to_s
      else
        ::Crawler::Data::URL.parse(link).to_s
      end
    end
  end

  def log(message, color = :default)
    puts message.colorize(color: color)
  end
end
