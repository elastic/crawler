#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'loghandlerbase')

module Crawler
  module LogHandler
    attr_reader :event_logger, :system_logger

    class StdoutHandler < LogHandler::Base
      def initialize(log_level)
        super

        @event_logger = Logger.new($stdout)
        system_logger = Logger.new($stdout)
        system_logger.level = log_level

        system_logger.formatter = proc do |_severity, datetime, _progname, msg|
          timestamp = datetime.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
          "[#{timestamp}] #{msg}\n"
        end

        @system_logger = system_logger
        # Add crawl id and stage to all logging events produced by this crawl
        # tagged_system_logger = StaticallyTaggedLogger.new(system_logger)
        # @system_logger = tagged_system_logger.tagged("crawl:#{crawl_id}", crawl_stage)
      end

      def log(message, message_log_level)
        case message_log_level
        when :debug
          @system_logger.debug(message)
        when :info
          @system_logger.info(message)
        when :warn
          @system_logger.warn(message)
        when :error
          @system_logger.error(message)
        else
          @system_logger.fatal(message)
        end
      end

    end
  end
end
