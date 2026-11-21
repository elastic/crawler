#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'proto')
require_dependency File.join(__dir__, 'stream')

module Crawler
  module Agent
    # Implements the CheckinV2 reconciliation loop: the component periodically reports the
    # observed state of its units and applies the expected configuration sent back by Agent.
    class CheckinService
      NAME = 'checkin'
      DEFAULT_INTERVAL = 5

      def initialize(client, channel, handler, logger:, interval: DEFAULT_INTERVAL)
        @client = client
        @channel = channel
        @handler = handler
        @logger = logger
        @interval = interval
        @mutex = Mutex.new
        @wakeup = ConditionVariable.new
        @running = false
      end

      # Blocks until the stream ends. Raises if the stream fails.
      def run
        @running = true
        @stream = Stream.new(@channel, Proto.rpc('CheckinV2'), name: NAME, logger: @logger) { |m| receive(m) }.start
        @logger.info('Checking in with Elastic Agent')
        sender = Thread.new { send_loop }
        @stream.join
      ensure
        @running = false
        request_checkin
        sender&.join(@interval)
      end

      def stop
        @running = false
        request_checkin
        @stream&.cancel('component stopping')
      end

      # Wakes the sender so the current state is reported without waiting for the next interval
      def request_checkin
        @mutex.synchronize { @wakeup.signal }
      end

      private

      def send_loop
        while @running
          send_checkin
          @mutex.synchronize { @wakeup.wait(@mutex, @interval) if @running }
        end
      end

      def send_checkin
        observed = @client.observed
        @logger.debug("Checking in: #{observed[:units].map { |u| "#{u[:id]}=#{u[:state]}" }.join(', ')}")
        @stream.write(Proto.build(:CheckinObserved, observed))
      rescue StandardError => e
        @logger.error("Failed to send a check-in: #{e.class}: #{e.message}")
      end

      def receive(message)
        expected = Proto.to_h(message)
        unless @client.apply_expected(expected)
          @logger.debug('Check-in received, nothing changed')
          return
        end

        @logger.info("Check-in received with #{expected[:units].size} unit(s), applying expected configuration")
        apply_expected
      ensure
        request_checkin
      end

      def apply_expected
        @handler.apply(@client)
      rescue StandardError => e
        @logger.error("Failed to apply the expected configuration: #{e.class}: #{e.message}")
        @logger.debug(e.backtrace.join("\n")) if e.backtrace
      end
    end
  end
end
