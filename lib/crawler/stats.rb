# frozen_string_literal: true

#
# This class is used for aggregating crawler metrics based on crawl events.
# It is used both for crawl-level and for node-level accounting.
#
module Crawler
  class Stats
    attr_reader :crawl_started_at, :crawl_finished_at

    def initialize
      @crawl_started_at = nil
      @crawl_finished_at = nil

      @fetched_pages_count = Concurrent::AtomicFixnum.new(0)
      @time_spent_crawling_msec = Concurrent::AtomicReference.new(0.0)
      @urls_allowed_count = Concurrent::AtomicFixnum.new(0)

      # This is used for tracking discovered URLs grouped by deny_reason
      @urls_denied_counts = hash_of_fixnums

      # This is used for tracking response counts by status code
      @status_code_counts = hash_of_fixnums
    end

    # Returns a hash with the default value being an atomic fixnum
    def hash_of_fixnums
      Concurrent::Hash.new { |h, v| h[v] = Concurrent::AtomicFixnum.new(0) }
    end

    #-----------------------------------------------------------------------------------------------
    # Returns the total crawl duration (in milliseconds) or nil if the crawl has not started yet
    def crawl_duration_msec
      return nil unless crawl_started_at

      end_time = crawl_finished_at || Time.monotonic_now
      ((end_time - crawl_started_at) * 1000).to_i
    end

    # Returns the total number of HTTP calls performed
    def fetched_pages_count
      @fetched_pages_count.value
    end

    # Returns the total number of unique URLs allowed during discovery
    def urls_allowed_count
      @urls_allowed_count.value
    end

    # Returns the total number of URLs skipped, grouped by deny reason
    def urls_denied_counts
      @urls_denied_counts.transform_values(&:value)
    end

    # Returns the total time (in milliseconds) spent on HTTP calls during this crawl
    def time_spent_crawling_msec
      @time_spent_crawling_msec.value
    end

    # Returns a hash with the breakdown of all HTTP responses by status codes
    def status_code_counts
      @status_code_counts.transform_values(&:value)
    end

    # Returns average response time (in milliseconds) seen during the crawl
    def average_response_time_msec
      fetched_pages_count.positive? ? time_spent_crawling_msec / fetched_pages_count : 0
    end

    #-----------------------------------------------------------------------------------------------
    # Receives a crawl event (see `EventGenerator`) and updates stats based on its contents
    def update_from_event(event)
      case event['event.action']
      when 'crawl-start'
        @crawl_started_at = Time.monotonic_now
      when 'crawl-end'
        @crawl_finished_at = Time.monotonic_now
      when 'url-discover'
        count_url_discover(event)
      when 'url-fetch'
        count_url_fetch(event)
      end
    end

    # Updates stats based on url-discover events
    def count_url_discover(event)
      if event.fetch('event.type') == :denied
        deny_reason = event.fetch('crawler.url.deny_reason')
        @urls_denied_counts[deny_reason].increment
      else
        @urls_allowed_count.increment
      end
    end

    # Updates stats based on url-fetch events
    def count_url_fetch(event)
      duration_msec = event.fetch('event.duration') / 1_000_000 # ECS events are measured in nanoseconds
      status_code = event.fetch('http.response.status_code').to_s

      @fetched_pages_count.increment
      @status_code_counts[status_code].increment
      @time_spent_crawling_msec.update { |v| v + duration_msec }
    end
  end
end
