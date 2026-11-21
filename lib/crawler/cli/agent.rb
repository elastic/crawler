#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'dry/cli'
require 'fileutils'

module Crawler
  module CLI
    class Agent < Dry::CLI::Command
      desc 'Run the crawler as an Elastic Agent component (connection details are read from STDIN)'

      option :checkin_interval, type: :integer, default: Crawler::Agent::CheckinService::DEFAULT_INTERVAL,
                                desc: 'Seconds between check-ins with Elastic Agent'
      option :data_dir, type: :string, desc: 'Directory for crawl output files (set by Elastic Agent)'

      def call(checkin_interval:, data_dir: nil, **)
        use_data_dir(data_dir)
        Crawler::Agent::Component.new(checkin_interval: checkin_interval.to_i).run
      rescue StandardError => e
        Crawler::CLI::Helpers.die("#{e.class}: #{e.message}")
      end

      private

      # Crawl output (failed bulk payloads, local logs) goes under the data directory Agent assigns
      def use_data_dir(data_dir)
        return if data_dir.to_s.empty?

        FileUtils.mkdir_p(data_dir)
        Dir.chdir(data_dir)
      end
    end
  end
end
