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

      # Elastic Agent picks the certificate for a component by the TLS server name (SNI), which is
      # the component id (e.g. "crawler-default"). Java TLS engines only send SNI automatically for
      # host names containing a dot, so the server name is set explicitly on every engine.
      class SniSslContext < Java::IoGrpcNettyShadedIoNettyHandlerSsl::DelegatingSslContext
        def initialize(context, server_name)
          super(context)
          @server_name = server_name
        end

        def initEngine(engine) # rubocop:disable Naming/MethodName
          return if @server_name.to_s.empty?

          params = engine.getSSLParameters
          params.setServerNames([Java::JavaxNetSsl::SNIHostName.new(@server_name)])
          engine.setSSLParameters(params)
        end
      end

      def self.channel(info)
        validate_address!(info.addr)
        builder = Java::IoGrpcNettyShadedIoGrpcNetty::NettyChannelBuilder.forTarget(info.addr)
        if info.tls?
          builder.sslContext(ssl_context(info))
        else
          builder.usePlaintext
        end
        builder.overrideAuthority(info.server_name) unless info.server_name.to_s.empty?
        builder.maxInboundMessageSize(info.max_message_size) if info.max_message_size.to_i.positive?
        builder.build
      end

      def self.validate_address!(addr)
        scheme = addr[%r{\A([a-z]+)://}i, 1]
        return unless scheme && LOCAL_ADDRESS_SCHEMES.include?(scheme.downcase)

        raise Error, "Unsupported Elastic Agent address #{addr}: only TCP addresses are supported"
      end

      def self.ssl_context(info)
        builder = Java::IoGrpcNettyShadedIoGrpcNetty::GrpcSslContexts.forClient
        builder.trustManager(pem_stream(info.ca_cert)) unless info.ca_cert.to_s.empty?
        builder.keyManager(pem_stream(info.peer_cert), pem_stream(info.peer_key)) unless info.peer_cert.to_s.empty?
        SniSslContext.new(builder.build, info.server_name)
      end

      def self.pem_stream(pem)
        java.io.ByteArrayInputStream.new(pem.to_s.to_java_bytes)
      end
    end
  end
end
