#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'logger'

require_dependency File.join(__dir__, '..', 'agent')
require_dependency File.join(__dir__, 'actions_service')
require_dependency File.join(__dir__, 'checkin_service')
require_dependency File.join(__dir__, 'client')
require_dependency File.join(__dir__, 'connection')
require_dependency File.join(__dir__, 'crawl_handler')
require_dependency File.join(__dir__, 'crawl_runner')
require_dependency File.join(__dir__, 'startup_info')

module Crawler
  module Agent
    # Entry point for running the crawler as an Elastic Agent component
    class Component
      NAME = 'crawler'
      SHUTDOWN_TIMEOUT = 30
      SIGNALS = %w[INT TERM].freeze

      def self.default_logger
        Crawler::Logging::CrawlLogger.new.tap do |logger|
          logger.add_handler(Crawler::Logging::Handler::StdoutHandler.new(Logger::INFO))
          logger.add_tags_to_log_handlers(['[agent]'])
        end
      end

      def initialize(stdin: $stdin, logger: nil, checkin_interval: CheckinService::DEFAULT_INTERVAL,
                     channel_factory: Connection.method(:channel))
        @stdin = stdin
        @logger = logger || self.class.default_logger
        @checkin_interval = checkin_interval
        @channel_factory = channel_factory
        @stopping = Concurrent::AtomicBoolean.new(false)
        @shutdown = Concurrent::AtomicBoolean.new(false)
      end

      # Blocks until Agent stops the component or the connection to Agent is lost
      def run
        info = StartupInfo.read(@stdin)
        @logger.info("Connecting to Elastic Agent #{info.agent_id} (#{info.agent_version}) at #{info.addr}")
        @channel = @channel_factory.call(info)
        build_services(Client.new(info, version_info:))
        trap_signals
        run_services
      ensure
        shutdown
      end

      def stop(reason = 'stop requested')
        return unless @stopping.make_true

        @logger.info("Stopping the component (#{reason})")
        shutdown
      end

      private

      def version_info
        { name: NAME, meta: { 'input' => NAME, 'version' => Crawler.version } }
      end

      def build_services(client)
        @runner = CrawlRunner.new(logger: @logger, on_change: ->(status) { @handler.crawl_status_changed(status) })
        @handler = CrawlHandler.new(@runner, logger: @logger, on_change: -> { @checkin.request_checkin })
        @checkin = CheckinService.new(client, @channel, @handler, logger: @logger, interval: @checkin_interval)
        @actions = ActionsService.new(client, @channel, @handler, logger: @logger)
      end

      def trap_signals
        SIGNALS.each do |signal|
          Signal.trap(signal) { Thread.new { stop("received SIG#{signal}") } }
        end
      end

      # Runs the protocol services until one of them finishes; a failing service takes the
      # whole component down so that Agent restarts it
      def run_services
        finished = Queue.new
        services = { checkin: @checkin, actions: @actions }
        threads = services.map { |name, service| Thread.new { run_service(name, service, finished) } }
        name, error = finished.pop
        raise error if error && @stopping.false?

        @logger.info("The #{name} service finished, shutting down")
      ensure
        shutdown
        threads&.each { |thread| thread.join(SHUTDOWN_TIMEOUT) }
      end

      def run_service(name, service, finished)
        service.run
        finished << [name, nil]
      rescue StandardError => e
        @logger.error("The #{name} service failed: #{e.class}: #{e.message}") if @stopping.false?
        finished << [name, e]
      end

      def shutdown
        return unless @shutdown.make_true

        @handler&.stop(timeout: SHUTDOWN_TIMEOUT)
        @actions&.stop
        @checkin&.stop
        @channel&.shutdownNow
      end
    end
  end
end
