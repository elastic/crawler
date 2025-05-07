#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'bson'
require 'concurrent'

module Crawler
  module API
    # This represents a crawl job. Individual crawls can be started and then tracked given an
    # initial configuration that defines which URLs to crawl and domains to follow, how to extract
    # and process content, and where to write the results.
    class Crawl
      INTERRUPTIBLE_SLEEP_INTERVAL = 0.5

      attr_reader :config, :crawl_queue, :seen_urls, :sink, :outcome, :outcome_message
      attr_accessor :executor

      def initialize(config)
        raise ArgumentError, 'Invalid config' unless config.is_a?(Config)
        raise ArgumentError, 'Missing domain allowlist' if config.domain_allowlist.empty?
        raise ArgumentError, 'Seed URLs need to be an enumerator' unless config.seed_urls.is_a?(Enumerator)
        raise ArgumentError, 'Need at least one Seed URL' unless config.seed_urls.any?

        @config = config
        @executor = HttpExecutor.new(config)
        @crawl_queue = Crawler::Data::UrlQueue.create(config)

        # A specialized data structure for keeping track of URLs we have already processed
        @seen_urls = Crawler::Data::SeenUrls.new

        # The flag used to control the shutdown process
        @shutdown_started = Concurrent::AtomicBoolean.new(false)

        # The module responsible for processing crawl results
        @sink = Crawler::OutputSink.create(config)

        # When set to +true+, the shutdown process will stop gracefully while preserving
        # the state of the crawl, which should allow us to resume the crawl later as needed.
        @allow_resume = false
      end

      delegate :system_logger, :events, :stats, to: :config
      delegate :rule_engine, to: :sink

      #---------------------------------------------------------------------------------------------
      def shutdown_started?
        @shutdown_started.true?
      end

      # Returns +true+ if the current crawl state should be preserved during shutdown
      def allow_resume?
        @allow_resume
      end

      def start_shutdown!(reason:, allow_resume: false)
        system_logger.info(
          "Received a shutdown request (#{reason}), starting the shutdown (allow_resume: #{allow_resume})..."
        )
        @allow_resume = allow_resume
        @shutdown_started.make_true
      end

      #---------------------------------------------------------------------------------------------
      # Waits for a specified number of seconds, stopping earlier if we are in a shutdown mode
      def interruptible_sleep(period)
        start_time = Time.now
        loop do
          break if shutdown_started?
          break if Time.now - start_time > period

          sleep(INTERRUPTIBLE_SLEEP_INTERVAL)
        end
      end

      #---------------------------------------------------------------------------------------------
      def coordinator
        @coordinator ||= Crawler::Coordinator.new(self)
      end

      #---------------------------------------------------------------------------------------------
      # Starts a new crawl described by the given config. The job is started immediately.
      def start! # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        events.crawl_start(
          url_queue_items: crawl_queue.length,
          seen_urls: seen_urls.count
        )
        ingestion_stats = coordinator.run_crawl!

        record_overall_outcome(coordinator.crawl_results)
      rescue StandardError => e
        log_exception(e, 'Unexpected error while running the crawl')
        record_outcome(
          outcome: :failure,
          message: 'Unexpected error while running the crawl, check system logs for details'
        )
      ensure
        # Execute hooks to either save the state or clean up after the crawl.
        # The actual cleanup and persistence implementation depends on specific UrlQueue and SeenUrls classes
        if allow_resume?
          system_logger.info('Not removing the crawl queue to allow the crawl to resume later')
          crawl_queue.save
          seen_urls.save
        else
          system_logger.info('Releasing resources used by the crawl...')
          crawl_queue.delete
          seen_urls.clear
          print_final_crawl_status
          print_crawl_ingestion_results(ingestion_stats) if config.output_sink.to_s == 'elasticsearch'
        end
      end

      # Starts a crawl of a single URL, specifically for the UrlTest CLI command
      def start_url_test!(endpoint) # rubocop:disable Metrics/AbcSize
        events.crawl_start(
          url_queue_items: crawl_queue.length,
          seen_urls: seen_urls.count
        )
        # Use the File sink regardless of what is set in the config
        @sink = Crawler::OutputSink::File.new(config)
        coordinator.run_urltest_crawl!(endpoint)
        record_overall_outcome(coordinator.crawl_results)
        print_url_test_results(coordinator.url_test_results)
      rescue StandardError => e
        log_exception(e, 'Unexpected error while running the crawl')
        record_outcome(
          outcome: :failure,
          message: 'Unexpected error while running the crawl, check system logs for details'
        )
      ensure
        crawl_queue.delete
        seen_urls.clear
      end

      #---------------------------------------------------------------------------------------------
      # Returns a hash with crawl-specific status information
      # Note: This is used by the `EventGenerator` class for crawl-status events and by the Crawler Status API.
      #       Please update OpenAPI specs if you add any new fields here.
      def status
        {
          queue_size: crawl_queue.length,
          pages_visited: stats.fetched_pages_count,
          urls_allowed: stats.urls_allowed_count,
          urls_denied: stats.urls_denied_counts,
          crawl_duration_msec: stats.crawl_duration_msec,
          crawling_time_msec: stats.time_spent_crawling_msec,
          avg_response_time_msec: stats.average_response_time_msec,
          active_threads: coordinator.active_threads,
          http_client: executor.http_client_status,
          status_codes: stats.status_code_counts
        }
      end

      private

      def record_overall_outcome(results)
        if config.output_sink != 'elasticsearch' || !config.purge_crawl_enabled
          # only need primary crawl results in this situation
          record_outcome(outcome: results[:primary][:outcome], message: results[:primary][:message])
          return
        end

        outcome = combined_outcome(results)
        message = "#{results[:primary][:message]} | #{results[:purge][:message]}"
        record_outcome(outcome:, message:)
      end

      def combined_outcome(results)
        if coordinator.url_test # ignore outcome of purge crawl if url test command
          results[:primary][:outcome] == :success
        else
          results[:primary][:outcome] == :success && results[:purge][:outcome] == :success ? :success : :failure
        end
      end

      def record_outcome(outcome:, message:)
        @outcome = outcome
        @outcome_message = message

        events.crawl_end(
          outcome:,
          message:,
          resume_possible: allow_resume?
        )
      end

      def log_exception(exception, message, **_kwargs)
        events.log_error(exception, message)
      end

      def print_url_test_results(url_test_results)
        puts "\n---- URL Test Results ----"
        url_test_results.each do |result|
          puts "- Attempted to crawl #{result.url}"
          puts "- Status code: #{result.status_code}"
          puts "- Content type: #{result.content_type}"
          puts "- Crawl duration (seconds): #{result.duration}"

          print_extracted_links(result)

          next unless result.is_a?(Crawler::Data::CrawlResult::Error)

          puts "  \nA helpful suggestion: #{result.suggestion_message}"
        end
        puts "\nYou can find the downloaded document under #{config.output_dir}"
      end

      def print_crawl_ingestion_results(ingestion_stats)
        return if ingestion_stats.nil?

        completed_stats = ingestion_stats.fetch(:completed, {})
        failed_stats = ingestion_stats.fetch(:failed, {})

        puts "\n---- Elasticsearch Ingestion Stats ----"
        unless completed_stats.empty?
          puts '- Completed'
          puts "  - Documents upserted: #{completed_stats.fetch(:docs_count, 0)}"
          puts "  - Volume (bytes): #{completed_stats.fetch(:docs_volume, 0)}"
        end

        return if failed_stats.empty?

        puts '- Failed'
        puts "  - Number of documents that failed to index: #{failed_stats.fetch(:docs_count, 0)}"
        puts "  - Volume (bytes): #{failed_stats.fetch(:docs_volume, 0)}"
      end

      def print_final_crawl_status # rubocop:disable Metrics/AbcSize
        crawl_status = status
        puts "\n---- Crawl Stats ----"
        puts "- Pages visited: #{crawl_status[:pages_visited]}"
        puts "- URLs allowed: #{crawl_status[:urls_allowed]}"
        puts '- URLs denied'
        puts "  - Already seen: #{crawl_status[:urls_denied][:already_seen]}"
        puts "  - Domain filter: #{crawl_status[:urls_denied][:domain_filter_denied]}"
        puts "- Crawl duration (seconds): #{crawl_status[:crawl_duration_msec] / 1000}"
        puts "- Crawling time (seconds): #{crawl_status[:crawling_time_msec] / 1000}"
        puts "- Average response time (seconds): #{crawl_status[:avg_response_time_msec] / 1000}"
      end

      def print_extracted_links(result)
        return unless result.is_a?(Crawler::Data::CrawlResult::HTML)

        puts '- Extracted links:'
        result.links.each do |link|
          puts "  - #{link}"
        end
      end
    end
  end
end
