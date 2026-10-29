#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'dry/cli'

module Crawler
  module CLI
    class Agent < Dry::CLI::Command
      desc 'Run the crawler as an Elastic Agent component (connection details are read from STDIN)'

      option :checkin_interval, type: :integer, default: Crawler::Agent::CheckinService::DEFAULT_INTERVAL,
                                desc: 'Seconds between check-ins with Elastic Agent'

      def call(checkin_interval:, **)
        Crawler::Agent::Component.new(checkin_interval: checkin_interval.to_i).run
      rescue StandardError => e
        Crawler::CLI::Helpers.die("#{e.class}: #{e.message}")
      end
    end
  end
end
