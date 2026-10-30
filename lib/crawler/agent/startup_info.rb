#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, '..', 'agent')
require_dependency File.join(__dir__, 'proto')

module Crawler
  module Agent
    # Connection details handed over by Elastic Agent on STDIN when it spawns the component
    class StartupInfo
      REQUIRED_SERVICE = :CheckinV2
      FIELDS = %i[
        addr server_name token ca_cert peer_cert peer_key services supports max_message_size agent_info
      ].freeze

      attr_reader(*FIELDS)

      def self.read(io)
        io.binmode if io.respond_to?(:binmode)
        data = io.read.to_s
        raise Error, 'No startup information received from Elastic Agent on STDIN' if data.empty?

        new(Proto.to_h(Proto.decode(:StartUpInfo, data)))
      end

      def initialize(attributes)
        FIELDS.each { |field| instance_variable_set("@#{field}", attributes[field]) }
        @services ||= []
        @supports ||= []
        validate!
      end

      def tls?
        !ca_cert.to_s.empty? || !peer_cert.to_s.empty?
      end

      def agent_id
        agent_info&.dig(:id)
      end

      def agent_version
        agent_info&.dig(:version)
      end

      private

      def validate!
        raise Error, 'Elastic Agent did not provide a gRPC address' if addr.to_s.empty?
        return if services.include?(REQUIRED_SERVICE)

        raise Error, "Elastic Agent does not offer the #{REQUIRED_SERVICE} service (offered: #{services.inspect})"
      end
    end
  end
end
