# frozen_string_literal: true

# An abstract URL Queue, used as a base class for all concrete implementations
module Crawler
  module Data
    module UrlQueue
      class Base
        # When should we start alerting the operator about the queue being almost full
        WARN_THRESHOLD_PCT = 90 # percent of the queue size limit

        # How often should we alert
        WARN_THRESHOLD_INTERVAL = 5.minutes

        #-------------------------------------------------------------------------------------------
        attr_reader :config, :last_threshold_alert_timestamp

        delegate :crawl_id, :system_logger, :to => :config

        def initialize(config)
          @config = config
          raise ArgumentError, 'Needs a config' unless config
        end

        #-------------------------------------------------------------------------------------------
        # Checks the size of the queue before putting any more items on it
        # Raises an exception if the queue is full
        def check_queue_size!
          raise NotImplementedError
        end

        # Returns the threshold value beyond which we will start alerting the operator via log
        # messages and asking them to look into the queue size issue
        def warning_threshold(size_limit)
          (WARN_THRESHOLD_PCT * size_limit / 100.0).to_i
        end

        # Returns the time in seconds since the last threshold alert or
        # WARN_THRESHOLD_INTERVAL if we have not alerted yet
        def time_since_last_threshold_alert
          return WARN_THRESHOLD_INTERVAL unless last_threshold_alert_timestamp
          Time.now - last_threshold_alert_timestamp
        end

        # Prints an alert about the queue size into the log, throttling it to make sure we do not
        # flood the logs with duplicate messages (logs once per WARN_THRESHOLD_PCT)
        def maybe_threshold_alert(message)
          if time_since_last_threshold_alert >= WARN_THRESHOLD_PCT
            system_logger.warn(message.squish.squeeze(' '))
            @last_threshold_alert_timestamp = Time.now
          end
        end

        #-------------------------------------------------------------------------------------------
        # Adds one item to the queue
        def push(_item)
          check_queue_size!
          raise NotImplementedError
        end

        # Pulls an item from the queue if available and returns it.
        # Returns +nil+ if the queue is empty.
        def fetch
          raise NotImplementedError
        end

        # Removes all items from the queue
        def clear
          raise NotImplementedError
        end

        # A method called when the crawler needs to release resources occupied by the queue
        def delete
          clear
        end

        # A method called when the crawler needs to stop and persist its state
        def save
          # nothing to do by default
        end

        #-------------------------------------------------------------------------------------------
        # Returns the length of the queue
        def length
          raise NotImplementedError
        end

        def empty?
          length == 0
        end

        def any?
          !empty?
        end
      end
    end
  end
end
