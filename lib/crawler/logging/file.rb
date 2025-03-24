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

    class FileHandler < LogHandler::Base
      def initialize(log_level, filename, rotation_period)
        super
        raise ArgumentError, 'Need a filename for FileHandler log handler!' unless filename

        # system logger setup
        system_logger = Logger.new(filename, rotation_period)
        system_logger.level = log_level
        # Set custom formatter to include timestamp
        system_logger.formatter = proc do |_severity, datetime, _progname, msg|
          timestamp = datetime.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
          "[#{timestamp}] #{msg}\n"
        end
        # convert system logger to a StaticallyTaggedLogger so we can support tagging
        @system_logger = StaticallyTaggedLogger.new(system_logger)
      end

      def log(message, message_log_level)
        case message_log_level
        when Logger::DEBUG
          @system_logger.debug(message)
        when Logger::INFO
          @system_logger.info(message)
        when Logger::WARN
          @system_logger.warn(message)
        when Logger::ERROR
          @system_logger.error(message)
        else
          @system_logger.fatal(message)
        end
      end

      def add_tags(*tags)
        @system_logger.tagged(tags)
      end

      def level(log_level)
        @system_logger.level = log_level
      end
    end
  end
end
