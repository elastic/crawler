#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'elasticsearch/api'

require_dependency File.join(__dir__, '..', 'errors')

module Utility
  class BulkQueue
    # Maximum number of operations in BULK Elasticsearch operation that will ingest the data
    DEFAULT_OP_COUNT_THRESHOLD = 100
    # Maximum size of either whole BULK Elasticsearch operation or one document in it
    DEFAULT_SIZE_THRESHOLD = 1 * 1024 * 1024 # 1 megabyte

    def initialize(op_count_threshold, size_threshold, system_logger)
      @op_count_threshold = (op_count_threshold || DEFAULT_OP_COUNT_THRESHOLD).freeze
      @size_threshold = (size_threshold || DEFAULT_SIZE_THRESHOLD).freeze

      @system_logger = system_logger
      @system_logger.debug(
        "Initialized BulkQueue with op_count_threshold #{@op_count_threshold} and size_threshold #{@size_threshold}."
      )

      @buffer = []
      @current_op_count = 0
      @current_buffer_size = 0
      @current_data_size = 0
    end

    def pop_all
      result = @buffer

      reset

      result
    end

    def add(operation, payload = nil)
      unless will_fit?(operation, payload)
        log = <<~LOG.squish
          Operation failed to add to bulk queue. Current operation count is #{@current_op_count}.
          Operation payload was #{bytesize(payload)} bytes, current buffer size is #{@current_buffer_size} bytes.
        LOG
        @system_logger.error(log)
        raise Errors::BulkQueueOverflowError
      end

      operation_size = bytesize(operation)
      payload_size = bytesize(payload)

      @current_op_count += 1
      @current_buffer_size += operation_size
      @current_buffer_size += payload_size
      @current_data_size += payload_size

      @buffer << operation

      @buffer << payload if payload
    end

    def will_fit?(operation, payload = nil)
      return false if @current_op_count + 1 > @op_count_threshold

      operation_size = bytesize(operation)
      payload_size = bytesize(payload)

      @current_buffer_size + operation_size + payload_size < @size_threshold
    end

    def current_stats
      {
        current_op_count: @current_op_count,
        current_buffer_size: @current_buffer_size
      }
    end

    def bytesize(item)
      return 0 unless item

      serialize(item).bytesize
    end

    private

    def serialize(document)
      return '' unless document

      Elasticsearch::API.serializer.dump(document)
    end

    def reset
      @current_op_count = 0
      @current_buffer_size = 0
      @current_data_size = 0

      @buffer = []
    end
  end
end
