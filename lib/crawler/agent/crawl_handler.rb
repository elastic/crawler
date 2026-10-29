#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'rufus-scheduler'

require_dependency File.join(__dir__, '..', 'agent')
require_dependency File.join(__dir__, 'config_mapper')

module Crawler
  module Agent
    # Reacts to policy changes reported by Agent (check-ins) and to actions: it keeps the
    # crawler configured, runs the configured schedule and starts, stops or reports on crawls.
    class CrawlHandler
      CRAWL_ACTION = 'crawl'
      STATUS_ACTION = 'status'
      STOP_ACTION = 'stop'

      def initialize(runner, logger:, on_change: nil)
        @runner = runner
        @logger = logger
        @on_change = on_change
        @params = nil
        @input = nil
        @scheduler = nil
      end

      def configured?
        !@params.nil?
      end

      #---------------------------------------------------------------------------------------------
      # Check-ins

      def apply(client)
        input = client.inputs.find { |unit| unit.config_type == ConfigMapper::INPUT_TYPE }
        output = client.outputs.find { |unit| unit.config_type == ConfigMapper::OUTPUT_TYPE }
        reject_unsupported_units(client, input, output)

        if input && output && !input.expected_stopped? && !output.expected_stopped?
          configure(input, output)
        else
          deactivate(input, output)
        end
      end

      def crawl_status_changed(status)
        return unless (input = @input)

        state = status[:status] == 'failure' ? :DEGRADED : :HEALTHY
        input.set_state(state, crawl_message(status), payload: { crawl: status })
        @on_change&.call
      end

      #---------------------------------------------------------------------------------------------
      # Actions

      def handle_action(action)
        case action[:name]
        when CRAWL_ACTION then start_crawl(trigger: 'action')
        when STATUS_ACTION then { configured: configured?, crawl: @runner.status }
        when STOP_ACTION then stop_crawl
        else raise ActionError, "Unknown action #{action[:name].inspect}"
        end
      end

      def start_crawl(trigger:)
        params = @params
        raise ActionError, 'The crawler has not received a valid configuration from Elastic Agent yet' unless params

        @runner.start(Crawler::API::Config.new(**params), trigger:)
      end

      def stop_crawl
        raise ActionError, 'No crawl is in progress' unless @runner.running?

        @runner.stop(reason: 'stop action received from Elastic Agent')
        { status: 'stopping', crawl_id: @runner.status[:crawl_id] }
      end

      def stop(timeout: nil)
        unschedule
        return unless @runner.running?

        @runner.stop(reason: 'component shutdown')
        @runner.wait(timeout)
      end

      private

      def configure(input, output)
        params = ConfigMapper.crawl_params(input:, output:, logger: @logger)
        config = Crawler::API::Config.new(**params)
        @params = params
        @input = input
        schedule(config.schedule)
        output.set_state(:HEALTHY, "Elasticsearch output configured (#{params[:elasticsearch][:host]})")
        input.set_state(:HEALTHY, configured_message(config))
        @logger.info("Crawler configured: #{configured_message(config)}")
        @logger.info('The running crawl keeps its previous configuration') if @runner.running?
      rescue ConfigMapper::OutputConfigError => e
        fail_units(e, output => "Invalid Elasticsearch output: #{e.message}",
                      input => 'Waiting for a valid Elasticsearch output')
      rescue StandardError => e
        fail_units(e, input => "Invalid crawler configuration: #{e.message}")
      end

      def fail_units(error, messages)
        @logger.error("Failed to configure the crawler: #{error.class}: #{error.message}")
        unschedule
        @params = nil
        messages.each { |unit, message| unit.set_state(:FAILED, message) }
      end

      def deactivate(input, output)
        if @runner.running? && (input.nil? || input.expected_stopped?)
          @runner.stop(reason: 'crawler input removed or stopped by Elastic Agent')
        end
        unschedule
        @params = nil
        @input = nil
        set_idle_state(input, :CONFIGURING, 'Waiting for an Elasticsearch output')
        set_idle_state(output, :HEALTHY, 'Waiting for a crawler input')
      end

      def set_idle_state(unit, state, message)
        return if unit.nil?

        unit.expected_stopped? ? unit.set_state(:STOPPED, 'Stopped') : unit.set_state(state, message)
      end

      def reject_unsupported_units(client, input, output)
        (client.units - [input, output]).each do |unit|
          next if unit.config.nil?

          state = unit.expected_stopped? ? :STOPPED : :FAILED
          unit.set_state(state, "Unsupported unit type #{unit.config_type.inspect}")
        end
      end

      def schedule(schedule)
        unschedule
        pattern = schedule&.dig(:pattern)
        return unless pattern

        @scheduler = Rufus::Scheduler.new
        @scheduler.cron(pattern, overlap: false) { scheduled_crawl }
        @logger.info("Crawls scheduled with cron pattern #{pattern.inspect}")
      end

      def scheduled_crawl
        start_crawl(trigger: 'schedule')
      rescue ActionError => e
        @logger.warn("Skipping scheduled crawl: #{e.message}")
      end

      def unschedule
        @scheduler&.shutdown(:kill)
        @scheduler = nil
      end

      def configured_message(config)
        pattern = config.schedule&.dig(:pattern)
        trigger = pattern ? "scheduled with cron pattern #{pattern.inspect}" : 'waiting for crawl actions'
        "Crawler configured for #{config.domain_allowlist.size} domain(s), #{trigger}"
      end

      def crawl_message(status)
        case status[:status]
        when 'running' then "Crawl #{status[:crawl_id]} running (trigger: #{status[:trigger]})"
        else "Crawl #{status[:crawl_id]} finished with outcome #{status[:status]}: #{status[:message]}"
        end
      end
    end
  end
end
