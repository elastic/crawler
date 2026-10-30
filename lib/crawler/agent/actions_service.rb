#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'json'

require_dependency File.join(__dir__, '..', 'agent')
require_dependency File.join(__dir__, 'proto')
require_dependency File.join(__dir__, 'stream')

module Crawler
  module Agent
    # Receives action requests from Agent, dispatches them to the handler and sends back a
    # single response per action.
    class ActionsService
      NAME = 'actions'
      INIT_ACTION_ID = 'init'

      def initialize(client, channel, handler, logger:)
        @client = client
        @channel = channel
        @handler = handler
        @logger = logger
      end

      # Blocks until the stream ends. Raises if the stream fails.
      def run
        @stream = Stream.new(@channel, Proto.rpc('Actions'), name: NAME, logger: @logger) { |m| receive(m) }.start
        respond(INIT_ACTION_ID, :SUCCESS, {})
        @logger.info('Listening for Elastic Agent actions')
        @stream.join
      end

      def stop
        @stream&.cancel('component stopping')
      end

      private

      def receive(message)
        action = Proto.to_h(message)
        @logger.info("Received action #{action[:name].inspect} (id: #{action[:id]}, type: #{action[:type]})")
        Thread.new { perform(action) }
      end

      def perform(action)
        status, result = execute(action)
        respond(action[:id], status, result)
      end

      def execute(action)
        return [:FAILED, { error: 'Diagnostics actions are not supported' }] if action[:type] == :DIAGNOSTICS

        result = @handler.handle_action(action.merge(params: parse_params(action[:params])))
        [:SUCCESS, result || {}]
      rescue ActionError => e
        @logger.warn("Action #{describe(action)} rejected: #{e.message}")
        [:FAILED, { error: e.message }]
      rescue StandardError => e
        @logger.error("Action #{describe(action)} failed: #{e.class}: #{e.message}")
        @logger.debug(e.backtrace.join("\n")) if e.backtrace
        [:FAILED, { error: "Action failed: #{e.message}" }]
      end

      def describe(action)
        "#{action[:name].inspect} (id: #{action[:id]})"
      end

      def respond(id, status, result)
        @stream.write(Proto.build(:ActionResponse, token: @client.token, id:, status:, result: result.to_json))
      rescue StandardError => e
        @logger.error("Failed to respond to action #{id}: #{e.class}: #{e.message}")
      end

      def parse_params(params)
        return {} if params.to_s.strip.empty?

        parsed = JSON.parse(params)
        return {} if parsed.nil?
        raise ActionError, 'Action params must be a JSON object' unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError => e
        raise ActionError, "Action params are not valid JSON: #{e.message}"
      end
    end
  end
end
