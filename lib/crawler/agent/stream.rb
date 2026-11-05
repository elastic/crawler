#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'concurrent'

module Crawler
  module Agent
    # A bidirectional gRPC stream. Messages received from Agent are passed to the block given
    # at construction, messages for Agent are sent with #write.
    class Stream
      class Observer
        include Java::IoGrpcStub::StreamObserver

        def initialize(stream)
          @stream = stream
        end

        def onNext(message) # rubocop:disable Naming/MethodName
          @stream.handle_message(message)
        end

        def onError(error) # rubocop:disable Naming/MethodName
          @stream.handle_error(error)
        end

        def onCompleted # rubocop:disable Naming/MethodName
          @stream.handle_completed
        end
      end

      attr_reader :name, :error

      def initialize(channel, rpc, name:, logger:, &on_message)
        @channel = channel
        @rpc = rpc
        @name = name
        @logger = logger
        @on_message = on_message
        @mutex = Mutex.new
        @finished = Concurrent::Event.new
        @cancelled = false
        @error = nil
      end

      def start
        call = @channel.newCall(@rpc, Java::IoGrpc::CallOptions::DEFAULT)
        @request = Java::IoGrpcStub::ClientCalls.asyncBidiStreamingCall(call, Observer.new(self))
        self
      end

      def write(message)
        @mutex.synchronize { @request.onNext(message) }
      end

      # Tears the stream down; errors caused by the cancellation are not reported by #join
      def cancel(reason)
        @cancelled = true
        @mutex.synchronize { @request.cancel(reason, nil) }
      rescue StandardError => e
        @logger.debug("Failed to cancel #{name} stream: #{e.message}")
      end

      def finished?
        @finished.set?
      end

      # Blocks until the stream ends; raises if it ended with an error
      def join(timeout = nil)
        @finished.wait(timeout)
        raise Error, "#{name} stream failed: #{@error}" if @error && !@cancelled

        finished?
      end

      def handle_message(message)
        @on_message.call(message)
      rescue StandardError => e
        @logger.error("Error while handling a message on the #{name} stream: #{e.class}: #{e.message}")
        @logger.debug(e.backtrace.join("\n")) if e.backtrace
      end

      def handle_error(error)
        @error = describe_error(error)
        @finished.set
      end

      # Includes the cause chain, which carries the useful detail for TLS and connection failures
      def describe_error(error)
        return error.to_s unless error.respond_to?(:getMessage)

        messages = []
        cause = error
        while cause && messages.size < 6
          messages << "#{cause.java_class.simple_name}: #{cause.getMessage}"
          # gRPC keeps the transport failure in the status rather than as the exception cause
          cause = cause.respond_to?(:getStatus) ? cause.getStatus.getCause || cause.getCause : cause.getCause
        end
        messages.join(' <- ')
      end

      def handle_completed
        @finished.set
      end
    end
  end
end
