#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, '..', 'agent')

module Crawler
  module Agent
    # Builds the mutual-TLS gRPC channel to Elastic Agent from the startup information
    module Connection
      LOCAL_ADDRESS_SCHEMES = %w[unix npipe].freeze

      def self.channel(info)
        validate_address!(info.addr)
        builder = Java::IoGrpc::Grpc.newChannelBuilder(info.addr, credentials(info))
        builder.overrideAuthority(info.server_name) unless info.server_name.to_s.empty?
        builder.maxInboundMessageSize(info.max_message_size) if info.max_message_size.to_i.positive?
        builder.build
      end

      def self.validate_address!(addr)
        scheme = addr[%r{\A([a-z]+)://}i, 1]
        return unless scheme && LOCAL_ADDRESS_SCHEMES.include?(scheme.downcase)

        raise Error, "Unsupported Elastic Agent address #{addr}: only TCP addresses are supported"
      end

      def self.credentials(info)
        return Java::IoGrpc::InsecureChannelCredentials.create unless info.tls?

        builder = Java::IoGrpc::TlsChannelCredentials.newBuilder
        builder.trustManager(pem_stream(info.ca_cert)) unless info.ca_cert.to_s.empty?
        builder.keyManager(pem_stream(info.peer_cert), pem_stream(info.peer_key)) unless info.peer_cert.to_s.empty?
        builder.build
      end

      def self.pem_stream(pem)
        java.io.ByteArrayInputStream.new(pem.to_s.to_java_bytes)
      end
    end
  end
end
