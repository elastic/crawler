#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')

module Crawler
  module Logging
    module Handler
      attr_reader :event_logger, :logger_instance

      class StdoutHandler < Handler::Base
        def initialize(log_level)
          super
          # logger instance setup
          logger_instance = Logger.new($stdout)
          logger_instance.level = log_level
          # Set a base format to include timestamp
          format_logger(logger_instance)
          # convert logger instance to a StaticallyTaggedLogger so we can support tagging
          @logger_instance = logger_instance
        end

        def log(message, message_log_level)
          case message_log_level
          when Logger::DEBUG
            @logger_instance.debug(message)
          when Logger::INFO
            @logger_instance.info(message)
          when Logger::WARN
            @logger_instance.warn(message)
          when Logger::ERROR
            @logger_instance.error(message)
          when Logger::FATAL
            @logger_instance.fatal(message)
          else
            @logger_instance << message
          end
        end

        def add_tags(*tags)
          # this function re-formats the log format with the provided tags
          format_logger(@logger_instance, tags.join(' '))
        end

        def format_logger(logger_instance, tags = nil)
          logger_instance.formatter = proc do |_severity, datetime, _progname, msg|
            timestamp = datetime.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
            if tags
              "[#{timestamp}] #{tags} #{msg}\n"
            else
              "[#{timestamp}] #{msg}\n"
            end
          end
        end

        def level(log_level)
          @logger_instance.level = log_level
        end
      end
    end
  end
end
