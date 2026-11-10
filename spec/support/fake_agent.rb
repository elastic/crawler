#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'securerandom'
require 'timeout'

module RSpec
  module Support
    # An in-process gRPC server that plays the Elastic Agent side of the V2 control protocol
    class FakeAgent
      CHECKIN = 'CheckinV2'
      ACTIONS = 'Actions'

      class Method
        include Java::IoGrpcStub::ServerCalls::BidiStreamingMethod

        def initialize(agent, name)
          @agent = agent
          @name = name
        end

        def invoke(response_observer)
          @agent.connected(@name, response_observer)
          Requests.new(@agent, @name)
        end
      end

      class Requests
        include Java::IoGrpcStub::StreamObserver

        def initialize(agent, name)
          @agent = agent
          @name = name
        end

        def onNext(message) # rubocop:disable Naming/MethodName
          @agent.received(@name, Crawler::Agent::Proto.to_h(FakeAgent.wire(message)))
        end

        def onError(_error) # rubocop:disable Naming/MethodName
          @agent.disconnected(@name)
        end

        def onCompleted # rubocop:disable Naming/MethodName
          @agent.disconnected(@name)
        end
      end

      attr_reader :name, :observed, :action_responses

      def initialize
        @name = "fake-agent-#{SecureRandom.hex(4)}"
        @observed = Queue.new
        @action_responses = Queue.new
        @responders = {}
        @mutex = Mutex.new
        @server = Java::IoGrpcInprocess::InProcessServerBuilder.forName(name).addService(service).build.start
      end

      def channel
        Java::IoGrpcInprocess::InProcessChannelBuilder.forName(name).build
      end

      def startup_info(**attributes)
        Crawler::Agent::StartupInfo.new({ addr: name, token: 'token', services: [:CheckinV2] }.merge(attributes))
      end

      def startup_info_bytes(**attributes)
        info = { addr: name, token: 'token', services: [:CheckinV2], agent_info: { id: 'agent-id', version: '9.9.9' } }
        Crawler::Agent::Proto.encode(Crawler::Agent::Proto.build(:StartUpInfo, info.merge(attributes)))
      end

      # The in-process transport hands objects over as-is; re-parsing them from bytes gives the
      # client the same DynamicMessage shapes it sees from a real Agent over the network
      def self.wire(message)
        Java::ComGoogleProtobuf::DynamicMessage.parseFrom(message.getDescriptorForType, message.toByteArray)
      end

      def send_expected(attributes)
        responder(CHECKIN).onNext(FakeAgent.wire(Crawler::Agent::Proto.build(:CheckinExpected, attributes)))
      end

      def send_action(attributes)
        responder(ACTIONS).onNext(FakeAgent.wire(Crawler::Agent::Proto.build(:ActionRequest, attributes)))
      end

      def complete(method)
        responder(method).onCompleted
      end

      def connected?(method)
        @mutex.synchronize { @responders.key?(method) }
      end

      def wait_for_connection(method, timeout: 5)
        wait_until(timeout:) { connected?(method) }
      end

      def next_observed(timeout: 5)
        pop(@observed, timeout:)
      end

      # Pops observed messages until one satisfies the block and returns it
      def observed_until(timeout: 5)
        deadline = Time.now + timeout
        loop do
          message = pop(@observed, timeout: [deadline - Time.now, 0.01].max)
          return message if yield(message)
        end
      end

      def next_action_response(timeout: 5)
        pop(@action_responses, timeout:)
      end

      def stop
        @server.shutdownNow
      end

      def connected(method, observer)
        @mutex.synchronize { @responders[method] = observer }
      end

      # Completes the response side like a server that finishes when the client does
      def disconnected(method)
        observer = @mutex.synchronize { @responders.delete(method) }
        observer&.onCompleted
      rescue StandardError
        nil
      end

      def received(method, message)
        (method == CHECKIN ? @observed : @action_responses) << message
      end

      private

      def responder(method)
        @mutex.synchronize { @responders.fetch(method) { raise "No #{method} stream connected" } }
      end

      def service
        definition = Java::IoGrpc::ServerServiceDefinition.builder('proto.ElasticAgent')
        [CHECKIN, ACTIONS].each do |method|
          definition.addMethod(
            Crawler::Agent::Proto.rpc(method),
            Java::IoGrpcStub::ServerCalls.asyncBidiStreamingCall(Method.new(self, method))
          )
        end
        definition.build
      end

      def pop(queue, timeout:)
        wait_until(timeout:) { !queue.empty? }
        queue.pop
      end

      def wait_until(timeout:, interval: 0.02)
        deadline = Time.now + timeout
        until yield
          raise Timeout::Error, "Condition not met within #{timeout}s" if Time.now > deadline

          sleep(interval)
        end
      end
    end

    module AgentHelpers
      def wait_until(timeout: 5, interval: 0.02)
        deadline = Time.now + timeout
        until yield
          raise Timeout::Error, "Condition not met within #{timeout}s" if Time.now > deadline

          sleep(interval)
        end
      end

      def agent_logger
        Crawler::Logging::CrawlLogger.new
      end
    end
  end
end

RSpec.configure do |config|
  config.include(RSpec::Support::AgentHelpers)
end
