#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

# logging monolith class that maintains
# a. list of log handlers
# b. routing function to route log messages to all handlers
module Crawler
  class CrawlLogger
    attr_reader :all_handlers

    def initialize
      # initialize with no handlers by default
      @all_handlers = []
    end

    # ------------------------------------------------------------
    def route_logs_to_handlers(message, message_log_level)
      all_handlers.each do |handler|
        handler.log(message, message_log_level)
      end
    end

    def debug(message)
      route_logs_to_handlers(message, Logger::DEBUG)
    end

    def info(message)
      route_logs_to_handlers(message, Logger::INFO)
    end

    def warn(message)
      route_logs_to_handlers(message, Logger::WARN)
    end

    def error(message)
      route_logs_to_handlers(message, Logger::ERROR)
    end

    def fatal(message)
      route_logs_to_handlers(message, Logger::FATAL)
    end

    def add(custom_log_level, message)
      route_logs_to_handlers(message, custom_log_level)
    end

    def <<(message)
      route_logs_to_handlers(message, nil)
    end

    # ------------------------------------------------------------
    def add_handler(new_handler)
      all_handlers.append(new_handler)
    end

    def add_tags_to_log_handlers(tags)
      all_handlers.each do |handler|
        handler.add_tags(tags)
      end
    end
  end
end
