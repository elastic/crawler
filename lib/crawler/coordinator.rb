#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'set'
require 'benchmark'
require 'concurrent/set'

# There are too many lint issues here to individually disable
# rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
module Crawler
  # The Coordinator is responsible for running an entire crawl from start to finish.
  class Coordinator # rubocop:disable Metrics/ClassLength
    SEED_LIST = 'seed-list'

    # How long to wait before retrying ingestion after a retryable error (like a r/o mode write)
    RETRY_INTERVAL = 10.seconds

    attr_reader :crawl, :seen_urls, :crawl_outcome, :outcome_message, :started_at, :task_executors

    delegate :events, :system_logger, :config, :executor, :sink, :rule_engine,
             :interruptible_sleep, :shutdown_started?, :allow_resume?,
             :crawl_queue, :seen_urls, :stats, to: :crawl

    def initialize(crawl)
      @crawl = crawl

      # The thread pool for executing crawl tasks (downloading, extraction, output)
      @task_executors = Concurrent::ThreadPoolExecutor.new(
        name: "crawler-tasks-#{config.crawl_id}",
        max_threads: config.threads_per_crawl,
        idletime: 0,             # Remove finished threads immediately, so that we could detect free capacity
        max_queue: 0,            # Don't allow tasks to wait in the queue if there are not enough workers
        synchronous: true,       # max_queue=0 does not mean 'unbounded'
        fallback_policy: :abort # Raise an error if we try to push too much work into the pool
      )

      # Setup crawl internal state
      @crawl_outcome = nil
      @outcome_message = nil
      @started_at = Time.now
    end

    #-----------------------------------------------------------------------------------------------
    # Returns crawl duration in seconds or +nil+ if crawl has not been started yet
    def crawl_duration
      started_at ? Time.now - started_at : nil
    end

    # Returns the number of active threads running crawl tasks
    def active_threads
      task_executors.length
    end

    #-----------------------------------------------------------------------------------------------
    def run_crawl!
      load_robots_txts
      enqueue_seed_urls
      enqueue_sitemaps

      system_logger.info("Starting the crawl with up to #{task_executors.max_length} parallel thread(s)...")

      # Run the crawl until it is time to stop
      until crawl_finished?
        if executors_available?
          run_crawl_loop
        else
          # Sleep for a bit if there are no available executors to avoid creating a hot loop
          system_logger.debug('No executors available, sleeping for a second...')
          sleep(1)
        end
        events.log_crawl_status(crawl)
      end

      # Close the sink to make sure all the in-flight content has been safely stored/indexed/etc
      system_logger.info('Closing the output sink before finishing the crawl...')
      sink.close

      # Final dump of crawl stats
      events.log_crawl_status(crawl, force: true)
      system_logger.info('Crawl shutdown complete')
    end

    private

    #-----------------------------------------------------------------------------------------------
    # Communicates the progress on a given crawl task via the system log and Java thread names
    def crawl_task_progress(crawl_task, message)
      progress_message = "#{crawl_task.inspect}: #{message}"
      java.lang.Thread.currentThread.name = progress_message
      system_logger.debug("Crawl task progress: #{progress_message}")
    end

    #-----------------------------------------------------------------------------------------------
    # Loads robots.txt for each configured domain and registers it
    def load_robots_txts
      config.domain_allowlist.each do |domain|
        next if config.robots_txt_service.registered?(domain)

        crawl_result = load_robots_txt(domain)
        system_logger.debug("Registering robots.txt result for #{domain}: #{crawl_result}")
        config.robots_txt_service.register_crawl_result(domain, crawl_result)
      end
    end

    #-----------------------------------------------------------------------------------------------
    # Fetches robots.txt for a given domain and returns it as a crawl result
    def load_robots_txt(domain)
      crawl_task = Crawler::Data::CrawlTask.new(
        url: domain.robots_txt_url,
        type: :robots_txt,
        depth: 1
      )
      crawl_task.authorization_header = config.http_header_service.authorization_header_for_url(crawl_task.url)
      crawl_result = execute_task(crawl_task, follow_redirects: true)

      # Handle redirect errors as 404s
      if crawl_result.is_a?(Crawler::Data::CrawlResult::RedirectError)
        system_logger.warn(
          "Treating a robots.txt redirect error for #{domain} as a 404 response: #{crawl_result.error}"
        )
        crawl_result = Crawler::Data::CrawlResult::Error.new(
          url: crawl_result.url,
          error: crawl_result.error,
          status_code: 404
        )
      elsif crawl_result.error?
        system_logger.warn("Error while fetching robots.txt for #{domain}: #{crawl_result.error}")
      else
        system_logger.info("Fetched robots.txt for #{domain} from '#{crawl_result.url}'")
      end

      crawl_result
    end

    #-----------------------------------------------------------------------------------------------
    # Seed the crawler with configured URLs
    def enqueue_seed_urls
      system_logger.info("Seeding the crawl with #{config.seed_urls.size} URLs...")
      add_urls_to_backlog(
        urls: config.seed_urls,
        type: :content,
        source_type: SEED_LIST,
        crawl_depth: 1
      )
    end

    #-----------------------------------------------------------------------------------------------
    # Seed the crawler with pre-configured sitemaps
    def enqueue_sitemaps
      if config.sitemap_urls.any?
        system_logger.info("Seeding the crawl with #{config.sitemap_urls.count} Sitemap URLs...")
        add_urls_to_backlog(
          urls: config.sitemap_urls,
          type: :sitemap,
          source_type: SEED_LIST,
          crawl_depth: 1
        )
      end

      return if config.sitemap_discovery_disabled

      valid_auto_discovered_sitemap_urls = fetch_valid_auto_discovered_sitemap_urls!
      return unless valid_auto_discovered_sitemap_urls.any?

      system_logger.info(
        "Seeding the crawl with #{valid_auto_discovered_sitemap_urls.count} " \
        'auto-discovered (via robots.txt) Sitemap URLs...'
      )
      add_urls_to_backlog(
        urls: valid_auto_discovered_sitemap_urls,
        type: :sitemap,
        source_type: SEED_LIST,
        crawl_depth: 1
      )
    end

    def fetch_valid_auto_discovered_sitemap_urls!
      config.robots_txt_service.sitemaps.each_with_object([]) do |sitemap, out|
        sitemap_url = Crawler::Data::URL.parse(sitemap)

        if sitemap_url.supported_scheme?
          out << sitemap_url
        else
          system_logger.warn("Skipping auto-discovered Sitemap URL #{sitemap} with unsupported URL scheme")
        end
      end
    end

    #-----------------------------------------------------------------------------------------------
    def set_outcome(outcome, message)
      @crawl_outcome = outcome
      @outcome_message = message
    end

    #-----------------------------------------------------------------------------------------------
    # Returns +true+ if there are any free executors available to run crawl tasks
    def executors_available?
      task_executors.length < task_executors.max_length
    end

    #-----------------------------------------------------------------------------------------------
    # Checks if we should terminate the crawl loop and sets the outcome value accordingly
    def crawl_finished?
      return true if crawl_outcome

      # Check if there are any active tasks still being processed
      return false if task_executors.length.positive?

      if crawl_queue.empty? && !shutdown_started?
        system_logger.info('Crawl queue is empty, finishing the crawl')
        set_outcome(:success, 'Successfully finished the crawl with an empty crawl queue')
        return true
      end

      if shutdown_started?
        set_outcome(
          :shutdown,
          "Terminated the crawl with #{crawl_queue.length} unprocessed URLs " \
          "due to a crawler shutdown (allow_resume=#{allow_resume?})"
        )
        system_logger.warn("Shutting down the crawl with #{crawl_queue.length} unprocessed URLs...")
        return true
      end

      if crawl_duration > config.max_duration
        outcome_message = <<~OUTCOME.squish
          The crawl is taking too long (elapsed: #{crawl_duration.to_i} sec, limit: #{config.max_duration} sec).
          Shutting down with #{crawl_queue.length} unprocessed URLs.
          If you would like to increase the limit, change the max_duration setting.
        OUTCOME
        set_outcome(:warning, outcome_message)
        system_logger.warn(outcome_message)
        return true
      end

      false
    end

    #-----------------------------------------------------------------------------------------------
    # Performs a single iteration of the crawl loop
    def run_crawl_loop
      return if shutdown_started?

      # Get a task to execute
      crawl_task = crawl_queue.fetch
      return unless crawl_task

      crawl_task.authorization_header = config.http_header_service.authorization_header_for_url(crawl_task.url)

      # Push the task to the queue for execution in a separate thread
      begin
        task_executors.post do
          execute_crawl_task(crawl_task)
        end
      rescue Concurrent::RejectedExecutionError => e
        system_logger.warn("Failed to schedule a crawl task: #{e}. Going to retry in a second...")
        interruptible_sleep(1)
        retry unless shutdown_started?
      end
    end

    #-----------------------------------------------------------------------------------------------
    def execute_crawl_task(crawl_task)
      # Fetch the page.
      crawl_result = execute_task(crawl_task)

      # Process and output the crawl result.
      process_crawl_result(crawl_task, crawl_result)
    rescue StandardError => e
      crawl_task_progress(crawl_task, 'unexpected exception')
      system_logger.error("Unexpected error while executing a crawl task #{crawl_task.inspect}: #{e.full_message}")
      raise
    end

    #-----------------------------------------------------------------------------------------------
    # Fetches a URL and logs info about the HTTP request/response.
    def execute_task(crawl_task, follow_redirects: false)
      crawl_task_progress(crawl_task, 'HTTP execution')
      executor.run(crawl_task, follow_redirects: follow_redirects).tap do |crawl_result|
        events.url_fetch(url: crawl_task.url, crawl_result: crawl_result, auth_type: crawl_task.auth_type)
      end
    end

    #-----------------------------------------------------------------------------------------------
    # Process a crawl_result:
    # - Extract canonical_url and add it to the backlog
    # - Extract links contained in the page and add them to the backlog
    # - Output the crawl_result to the sink
    def process_crawl_result(crawl_task, crawl_result)
      crawl_task_progress(crawl_task, 'processing result')

      # Extract and enqueue all links from the crawl result
      start_time = Time.now
      duration = Benchmark.measure { extract_and_enqueue_links(crawl_task, crawl_result) }
      end_time = Time.now

      # Check page against rule engine before sending to an output sink
      output_crawl_result_outcome = rule_engine.output_crawl_result_outcome(crawl_result)
      extracted_event = {
        url: crawl_result.url,
        type: :allowed,
        start_time: start_time,
        end_time: end_time,
        duration: duration,
        outcome: :success
      }

      # Send the results to the output configured for this crawl unless it is denied by a rule
      if output_crawl_result_outcome.denied?
        extracted_event.merge!(
          type: :denied,
          deny_reason: output_crawl_result_outcome.deny_reason,
          message: output_crawl_result_outcome.message
        )
      elsif crawl_task.content?
        crawl_task_progress(crawl_task, 'ingesting the result')
        outcome = output_crawl_result(crawl_result)
        extracted_event.merge!(outcome)
      end

      # Content extraction complete, log an event about it
      events.url_extracted(**extracted_event)
    end

    #-----------------------------------------------------------------------------------------------
    # Extracts links from a given crawl result and pushes them into the crawl queue for processing
    def extract_and_enqueue_links(crawl_task, crawl_result)
      return if crawl_result.error?

      crawl_task_progress(crawl_task, 'extracting links')
      return enqueue_redirect_link(crawl_task, crawl_result) if crawl_result.redirect?
      return extract_and_enqueue_html_links(crawl_task, crawl_result) if crawl_result.html?

      extract_and_enqueue_sitemap_links(crawl_task, crawl_result) if crawl_result.sitemap?
    end

    #-----------------------------------------------------------------------------------------------
    def enqueue_redirect_link(crawl_task, crawl_result)
      add_urls_to_backlog(
        urls: [crawl_result.location],
        type: crawl_task.type,
        source_type: :redirect,
        source_url: crawl_task.url,
        crawl_depth: crawl_task.depth,
        redirect_chain: crawl_result.redirect_chain + [crawl_task.url]
      )
    end

    #-----------------------------------------------------------------------------------------------
    def extract_and_enqueue_html_links(crawl_task, crawl_result)
      canonical_link = crawl_result.canonical_link
      if canonical_link
        # If there is a valid canonical URL defined for the crawl_result,
        # add it to the backlog, so it can be visited during this crawl.
        #
        # We do not increment the depth, because we want to be sure that the canonical URL is visited.
        if canonical_link.valid?
          add_urls_to_backlog(
            urls: [canonical_link.to_url],
            type: :content,
            source_type: :canonical_url,
            source_url: crawl_task.url,
            crawl_depth: crawl_task.depth
          )
        else
          system_logger.warn(
            "Failed to parse canonical URL '#{canonical_link.link}' on '#{crawl_result.url}': #{canonical_link.error}"
          )
        end
      end

      # Extract all links, analyze them and create crawl tasks for those we want to follow
      links = extract_links(crawl_result, crawl_depth: crawl_task.depth + 1)
      return unless links.any?

      add_urls_to_backlog(
        urls: links,
        type: :content,
        source_type: :organic,
        source_url: crawl_task.url,
        crawl_depth: crawl_task.depth + 1
      )
    end

    #-----------------------------------------------------------------------------------------------
    def extract_and_enqueue_sitemap_links(crawl_task, crawl_result)
      result = crawl_result.extract_links
      limit_reached, error = result.values_at(:limit_reached, :error)
      system_logger.warn("Too many links in a sitemap '#{crawl_result.url}': #{error}") if limit_reached

      %i[sitemap content].each do |link_type|
        extracted_links = result.fetch(:links).fetch(link_type)
        good_links = Set.new
        extracted_links.each do |link|
          unless link.valid?
            system_logger.warn(
              "Failed to parse a #{link_type} link '#{link.link}' from sitemap '#{crawl_result.url}': #{link.error}"
            )
            next
          end
          good_links << link.to_url
        end

        add_urls_to_backlog(
          urls: good_links,
          type: link_type,
          source_type: :sitemap,
          source_url: crawl_task.url,
          crawl_depth: crawl_task.depth # Do not increase depth since sitemaps are not treated as pages
        )
      end
    end

    #-----------------------------------------------------------------------------------------------
    def extract_links(crawl_result, crawl_depth:)
      extracted_links = crawl_result.extract_links(limit: config.max_extracted_links_count)
      links, limit_reached = extracted_links.values_at(:links, :limit_reached)
      system_logger.warn("Too many links on the page '#{crawl_result.url}'") if limit_reached

      Set.new.tap do |good_links|
        links.each do |link|
          unless link.valid?
            system_logger.warn("Failed to parse a link '#{link.link}' on '#{crawl_result.url}': #{link.error}")
            next
          end

          if link.rel_nofollow? || crawl_result.meta_nofollow?
            events.url_discover_denied(
              url: link.to_url,
              source_url: crawl_result.url,
              crawl_depth: crawl_depth,
              deny_reason: :nofollow
            )
            next
          end

          good_links << link.to_url
        end
      end
    end

    #-----------------------------------------------------------------------------------------------
    # Outputs the results of a single URL processing to an output module configured for the crawl
    def output_crawl_result(crawl_result)
      sink.write(crawl_result).tap do |outcome|
        # Make sure we have an outcome of the right type (helps troubleshoot sink implementations)
        unless outcome.is_a?(Hash)
          error = "Expected to return an outcome object from the sink, returned #{outcome.inspect} instead"
          raise ArgumentError, error
        end
      end
    rescue StandardError => e
      if crawl.retryable_error?(e) && !shutdown_started?
        system_logger.warn("Retryable error during content ingestion: #{e}. Going to retry in #{RETRY_INTERVAL}s...")
        interruptible_sleep(RETRY_INTERVAL)
        retry
      end

      sink.failure("Unexpected exception while sending crawl results to the output sink: #{e}")
    end

    #-----------------------------------------------------------------------------------------------
    # Adds a set of URLs to the backlog for processing (if they are OK to follow)
    def add_urls_to_backlog(urls:, type:, source_type:, crawl_depth:, source_url: nil, redirect_chain: []) # rubocop:disable Metrics/ParameterLists
      return unless urls.any?

      allowed_urls = Set.new
      added_urls_count = 0

      # Check all URLs and filter out the ones we should actually crawl
      urls.each do |url| # rubocop:disable Metrics/BlockLength
        if shutdown_started?
          system_logger.warn(<<~LOG.squish)
            Received shutdown request while adding #{urls.count} URL(s) to the crawl queue.
            Some URLs have been skipped and may be missed if/when the crawl resumes.
          LOG
          break
        end

        # Skip if we have already added this URL to the backlog
        url = url.normalized_url
        next if allowed_urls.include?(url)

        # Skip unless this URL is allowed
        discover_outcome = check_discovered_url(
          url: url,
          type: type,
          source_url: source_url,
          crawl_depth: crawl_depth
        )
        next unless discover_outcome == :allow

        allowed_urls << url
        added_urls_count += 1

        add_url_to_backlog(
          url: url,
          type: type,
          source_type: source_type,
          crawl_depth: crawl_depth,
          source_url: source_url,
          redirect_chain: redirect_chain
        )
      end

      # Seeding complete, log about it
      return unless added_urls_count.positive?

      system_logger.info("Added #{added_urls_count} URLs from a #{source_type} source to the queue...")
      events.crawl_seed(added_urls_count, type: :content) if source_type == SEED_LIST
    end

    #-----------------------------------------------------------------------------------------------
    # Adds a single url to the backlog for processing and logs an event associated with it
    # If the queue is full, drops the item on the floor and logs about it.
    def add_url_to_backlog(url:, type:, source_type:, crawl_depth:, source_url:, redirect_chain: []) # rubocop:disable Metrics/ParameterLists
      crawl_queue.push(
        Crawler::Data::CrawlTask.new(
          url: url,
          type: type,
          depth: crawl_depth,
          redirect_chain: redirect_chain
        )
      )

      events.url_seed(
        url: url,
        source_url: source_url,
        type: type,
        source_type: source_type,
        crawl_depth: crawl_depth
      )
    rescue Crawler::Data::UrlQueue::TransientError => e
      # We couldn't visit the URL, so let's remove it from the seen URLs list
      seen_urls.delete(url)

      # Doing this on debug level not to flood the logs when the queue is full
      # The queue itself will log about its state on the warning log level
      system_logger.debug("Failed to add a crawler task into the processing queue: #{e}")
      events.url_discover_denied(
        url: url,
        source_url: source_url,
        crawl_depth: crawl_depth,
        deny_reason: :queue_full
      )
    end

    #-----------------------------------------------------------------------------------------------
    # Receives a newly-discovered url, makes a decision on what to do with it and records it in the log
    # FIXME: Feels like we need a generic way of encoding URL decisions, probably in the rules engine
    def check_discovered_url(url:, type:, source_url:, crawl_depth:) # rubocop:disable Metrics/PerceivedComplexity
      discover_event = {
        url: url,
        source_url: source_url,
        crawl_depth: crawl_depth
      }

      # Make sure it is an HTTP(S) link
      # FIXME: Feels like this should be a rules engine rule (which protocols to allow)
      unless url.supported_scheme?
        events.url_discover_denied(**discover_event.merge(deny_reason: :incorrect_protocol))
        return :deny
      end

      # Check URL length
      # FIXME: Feels like this should be a rules engine rule
      if url.request_uri.length > config.max_url_length
        events.url_discover_denied(**discover_event.merge(deny_reason: :link_too_long))
        return :deny
      end

      # Check URL segments limit
      # FIXME: Feels like this should be a rules engine rule
      if url.path_segments_count > config.max_url_segments
        events.url_discover_denied(**discover_event.merge(deny_reason: :link_with_too_many_segments))
        return :deny
      end

      # Check URL query parameters limit
      # FIXME: Feels like this should be a rules engine rule
      if url.params_count > config.max_url_params
        events.url_discover_denied(**discover_event.merge(deny_reason: :link_with_too_many_params))
        return :deny
      end

      # Check crawl rules to make sure we are allowed to crawl this URL
      # Please note: We check the rules before crawl-level limits, so that a single URL would
      #              retain its deny reason no matter where we find it (reduces confusion).
      # Sitemaps:    Sitemaps are treated specially and not checked against the rule engine.
      #              Otherwise they would be restricted to the same domain and also have to
      #              adhere to the configured crawl rules.
      discover_url_outcome = rule_engine.discover_url_outcome(url) unless type == :sitemap
      if discover_url_outcome&.denied?
        events.url_discover_denied(
          **discover_event.merge(
            deny_reason: discover_url_outcome.deny_reason,
            message: discover_url_outcome.message
          )
        )
        return :deny
      end

      # Check if we went deep enough and should stop here
      if crawl_depth > config.max_crawl_depth
        events.url_discover_denied(**discover_event.merge(deny_reason: :link_too_deep))
        return :deny
      end

      # Check if we have reached the limit on the number of unique URLs we have seen
      if seen_urls.count >= config.max_unique_url_count
        events.url_discover_denied(**discover_event.merge(deny_reason: :too_many_unique_links))
        return :deny
      end

      # Skip URLs we have already seen before (and enqueued for processing)
      # Warning: This should be the last check since it adds the URL to the seen_urls and
      #          we don't want to add a URL as seen if we could deny it afterwards
      unless seen_urls.add?(url)
        events.url_discover_denied(**discover_event.merge(deny_reason: :already_seen))
        return :deny
      end

      # Finally, if the URL is considered OK to crawl, record it as allowed
      events.url_discover(**discover_event.merge(type: :allowed))

      :allow
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
