#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'unit')

module Crawler
  module Agent
    # State of the V2 control protocol session: what Agent expects from the component
    # (units, component config) and what the component reports back on every check-in.
    class Client
      attr_reader :token, :agent_info, :units, :component_idx, :features_idx, :component, :version_info

      def initialize(startup_info, version_info:)
        @token = startup_info.token
        @agent_info = startup_info.agent_info
        @version_info = version_info
        @version_info_sent = false
        @units = []
        @component = nil
        @component_idx = 0
        @features_idx = 0
        @mutex = Mutex.new
      end

      # Applies a CheckinExpected message and returns +true+ when anything changed
      def apply_expected(expected)
        @mutex.synchronize do
          return false unless changed?(expected)

          @agent_info = expected[:agent_info] if expected[:agent_info]
          @component = expected[:component] if expected[:component]
          @component_idx = expected[:component_idx].to_i
          @features_idx = expected[:features_idx].to_i
          sync_units(expected[:units] || [])
          true
        end
      end

      # Attributes of the CheckinObserved message describing the current state of the component
      def observed
        @mutex.synchronize do
          message = {
            token:,
            units: @units.map(&:to_observed),
            features_idx:,
            component_idx:,
            supports: [],
            pid: Process.pid
          }
          message[:version_info] = version_info unless @version_info_sent
          @version_info_sent = true
          message
        end
      end

      def inputs
        @mutex.synchronize { @units.select(&:input?) }
      end

      def outputs
        @mutex.synchronize { @units.select(&:output?) }
      end

      private

      def changed?(expected)
        return true if @units.empty? || indexes_changed?(expected)

        current = @units.map { |unit| [unit.id, unit.type, unit.config_idx, unit.log_level, unit.expected_state] }
        wanted = (expected[:units] || []).map do |unit|
          [unit[:id], unit[:type], unit[:config_state_idx], unit[:log_level], unit[:state]]
        end
        current.sort != wanted.sort
      end

      def indexes_changed?(expected)
        @component_idx != expected[:component_idx].to_i || @features_idx != expected[:features_idx].to_i
      end

      def sync_units(expected_units)
        existing = @units.to_h { |unit| [unit.key, unit] }
        @units = expected_units.map do |expected|
          unit = existing[[expected[:id], expected[:type]]]
          unit ? unit.tap { |u| u.update(expected) } : Unit.new(expected)
        end
      end
    end
  end
end
