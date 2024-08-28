#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'rufus-scheduler'

module Crawler
  module CLI
    class Schedule < Dry::CLI::Command
      desc 'Schedule a recurring crawl of the site'

      argument :crawl_config, required: true, desc: 'Path to crawl config file'

      option :es_config, desc: 'Path to elasticsearch config file'

      def call(crawl_config:, es_config: nil, **)
        crawl_config = Crawler::CLI::Helpers.load_crawl_config(crawl_config, es_config)
        if crawl_config.schedule.nil? || crawl_config.schedule[:interval].nil?
          raise ArgumentError, 'No schedule found in config file'
        end

        crawl_config.system_logger.info("Schedule initialized with an interval of #{crawl_config.schedule[:interval]}")

        # Schedule a recurrent task based on the value in `schedule.interval`.
        # Setting overlap=false prevents multiple tasks from spawning when a crawl
        # task is longer than the schedule interval.
        scheduler = Rufus::Scheduler.new

        # TODO overlap not working, investigate
        scheduler.cron(crawl_config.schedule[:interval], blocking=true, overlap=false) do
          crawl_config.system_logger.info("Beginning a scheduled crawl...")
          crawl = Crawler::API::Crawl.new(crawl_config)
          crawl.start!
          crawl_config.system_logger.info("Scheduled crawl complete.")
        end
        scheduler.join
      end
    end
  end
end
