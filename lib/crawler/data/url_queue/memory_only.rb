#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'concurrent/array'
require_dependency File.join(__dir__, 'base')

# A concrete implementation of the URL Queue using an in-memory data store with a fixed limit
module Crawler
  module Data
    module UrlQueue
      class MemoryOnly < Base
        attr_reader :memory_size_limit, :memory_queue

        delegate :length, :clear, to: :memory_queue

        def initialize(*)
          super
          setup_memory_queue
        end

        def setup_memory_queue
          @memory_size_limit = (config.url_queue_size_limit || 10_000).to_i
          raise ArgumentError, 'Queue size limit should be a positive number' if memory_size_limit < 1

          # TODO: Order elements by URL path length to perform a breadth-first crawl
          @memory_queue = Concurrent::Array.new
          system_logger.info("Initialized an in-memory URL queue for up to #{memory_size_limit} URLs")
        end

        # Checks the size of the queue before putting any more items on it
        # Raises an exception if the queue is full
        def check_queue_size!
          current_items = memory_queue.length
          if current_items >= memory_size_limit
            maybe_threshold_alert(
              <<~LOG
                In-memory URL queue is full (#{current_items} items).
                New URLs will not be added to it until there is more space available.
                This may lead to missing pages in your search index.
              LOG
            )
            raise Crawler::Data::UrlQueue::QueueFullError,
                  "Too many items in URL queue: #{current_items} >= #{memory_size_limit}"
          end

          return unless current_items >= warning_threshold(memory_size_limit)

          maybe_threshold_alert(
            <<~LOG
              In-memory URL queue is #{WARN_THRESHOLD_PCT}% full (#{current_items} items).
              If we hit the limit of #{memory_size_limit} in-flight items,
              the crawler will be forced to start dropping new URLs,
              which may lead to missing pages in your search index.
            LOG
          )
        end

        # Adds an item into the queue
        def push(item)
          check_queue_size!
          memory_queue << item
        end

        # Pulls an item from the queue if available and returns it.
        # Returns +nil+ if the queue is empty.
        def fetch
          memory_queue.shift
        end
      end
    end
  end
end
