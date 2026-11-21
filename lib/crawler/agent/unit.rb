#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Agent
    # A unit is a single input or output from the agent policy assigned to this component.
    # It tracks what Agent expects (configuration and state) and what the component observes.
    class Unit
      attr_reader :id, :type, :expected_state, :config_idx, :config, :log_level, :state, :message, :payload

      def initialize(expected)
        @mutex = Mutex.new
        @state = :STARTING
        @message = ''
        @payload = nil
        @config = nil
        update(expected)
      end

      # Applies a UnitExpected message. The configuration is only included when it changed.
      def update(expected)
        @id = expected[:id]
        @type = expected[:type]
        @expected_state = expected[:state]
        @config_idx = expected[:config_state_idx]
        @log_level = expected[:log_level]
        @config = expected[:config] if expected[:config]
      end

      def key
        [id, type]
      end

      def input?
        type == :INPUT
      end

      def output?
        type == :OUTPUT
      end

      def expected_stopped?
        expected_state == :STOPPED
      end

      def config_type
        config&.dig(:type)
      end

      def source
        config&.dig(:source) || {}
      end

      def set_state(state, message, payload: :keep)
        @mutex.synchronize do
          @state = state
          @message = message.to_s
          @payload = payload unless payload == :keep
        end
      end

      def to_observed
        @mutex.synchronize do
          { id:, type:, config_state_idx: config_idx, state:, message:, payload: }
        end
      end

      def to_s
        "#{type.to_s.downcase} unit #{id} (#{config_type || 'unconfigured'})"
      end
    end
  end
end
