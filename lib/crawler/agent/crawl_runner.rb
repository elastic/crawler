#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'time'

require_dependency File.join(__dir__, '..', 'agent')

module Crawler
  module Agent
    # Runs at most one crawl at a time in a background thread and tracks its status
    class CrawlRunner
      def initialize(logger:, on_change: nil)
        @logger = logger
        @on_change = on_change
        @mutex = Mutex.new
        @thread = nil
        @crawl = nil
        @status = nil
      end

      # Starts a crawl with the given config factory. Raises ActionError if a crawl is in progress.
      def start(config, trigger:)
        @mutex.synchronize do
          raise ActionError, "A crawl is already in progress (crawl id: #{@status[:crawl_id]})" if @thread&.alive?

          @status = { crawl_id: config.crawl_id, status: 'running', trigger: trigger.to_s, started_at: now }
          @thread = Thread.new { run(config) }
        end
        notify
        status
      end

      def running?
        @mutex.synchronize { @thread&.alive? || false }
      end

      def status
        @mutex.synchronize { @status&.dup }
      end

      # Asks the running crawl to shut down gracefully, if any
      def stop(reason:)
        crawl = @mutex.synchronize { @crawl }
        crawl&.start_shutdown!(reason:)
      end

      def wait(timeout = nil)
        thread = @mutex.synchronize { @thread }
        thread&.join(timeout)
      end

      private

      def run(config)
        @logger.info("Starting crawl #{config.crawl_id} (#{@status[:trigger]})")
        crawl = Crawler::API::Crawl.new(config)
        @mutex.synchronize { @crawl = crawl }
        crawl.start!
        finish(crawl.outcome, crawl.outcome_message)
      rescue StandardError => e
        @logger.error("Crawl #{config.crawl_id} failed: #{e.class}: #{e.message}")
        finish(:failure, e.message)
      ensure
        @mutex.synchronize { @crawl = nil }
      end

      def finish(outcome, message)
        @mutex.synchronize do
          @status = @status.merge(status: outcome.to_s, message: message.to_s, finished_at: now)
        end
        @logger.info("Crawl #{@status[:crawl_id]} finished with outcome #{outcome}: #{message}")
        notify
      end

      def notify
        @on_change&.call(status)
      end

      def now
        Time.now.utc.iso8601
      end
    end
  end
end
