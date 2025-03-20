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

    def initialize(log_level)

      # initialize with default stdout handler
      @all_handlers = [Crawler::LogHandler::StdoutHandler.new(log_level)]
    end

    def list_all_handlers
      all_handlers.each do |handler|
        puts handler
      end
    end

    # ------------------------------------------------------------
    def all_handlers_log(message, message_log_level)
      all_handlers.each do |handler|
        handler.log(message, message_log_level)
      end
    end

    def debug(message)
      all_handlers_log(message, :debug)
    end

    def info(message)
      all_handlers_log(message, :info)
    end

    def warn(message)
      all_handlers_log(message, :warn)
    end

    def error(message)
      all_handlers_log(message, :error)
    end

    def fatal(message)
      all_handlers_log(message, :fatal)
    end

    # ------------------------------------------------------------
    def add_handler
      raise NotImplementedError
    end

    def route_logs_to_handlers
      raise NotImplementedError
    end
  end
end
