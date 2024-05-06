#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module HttpUtils
    class BaseError < StandardError
      # No suggestions by default
      def suggestion_message
        nil
      end
    end

    class RequestTimeout < BaseError
      def initialize(url)
        super("Timed-out requesting data from: #{url}")
      end
    end

    class ResponseTooLarge < BaseError; end

    class InvalidHost < BaseError; end

    #-----------------------------------------------------------------------------
    class InvalidEncoding < BaseError
      def new(encoding)
        @encoding = encoding
      end

      def message
        "Unsupported content encoding type used by the server: #{encoding}"
      end

      def supported_encodings
        Crawler::HttpClient::CONTENT_DECODERS.keys
      end

      def suggestion_message
        <<~MSG
          The crawler understands the following encodings: #{supported_encodings.join(', ')}.
          Try disabling HTTP content compression in the crawler configuration
          before running your crawl.
        MSG
      end
    end

    #-----------------------------------------------------------------------------
    class BaseErrorFromJava < BaseError
      attr_reader :java_exception, :root_cause

      # Returns the root cause of a series of Java exceptions
      def self.exception_root_cause(exception)
        exception.cause ? exception_root_cause(exception.cause) : exception
      end

      def initialize(java_exception)
        @java_exception = java_exception
        @root_cause = self.class.exception_root_cause(java_exception)
        super(format_message(root_cause))
      end

      # Generates a user-facing error message for a given root cause exception
      def format_message(root_cause)
        "#{root_cause.java_class.name}: #{root_cause.message}"
      end
    end

    class SocketTimeout < BaseErrorFromJava; end

    class ConnectTimeout < BaseErrorFromJava; end

    #-----------------------------------------------------------------------------
    class NoHttpResponseError < BaseErrorFromJava
      def self.for_proxy_host(error:, proxy_host:)
        error_class = proxy_host ? NoProxyHttpResponseError : self
        error_class.new(error)
      end

      def potential_cause
        'the health of the remote server'
      end

      def suggestion_message
        "Check #{potential_cause} before trying again."
      end
    end

    class NoProxyHttpResponseError < NoHttpResponseError
      def potential_cause
        'your proxy server configuration or the health of the remote server'
      end
    end

    #-----------------------------------------------------------------------------
    class SslException < BaseErrorFromJava
      DISABLE_SSL = 'disable SSL certificate validation (non-production environments only)'

      def self.for_java_error(error) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        root_cause = exception_root_cause(error)
        error_class =
          case root_cause
          when java.security.cert.CertificateExpiredException
            SslCertificateExpiredError
          when java.security.cert.CertificateNotYetValidException
            SslCertificateNotYetValidError
          when java.security.cert.CertificateRevokedException
            SslCertificateRevokedError
          when javax.net.ssl.SSLPeerUnverifiedException
            SslHostNameError
          when javax.net.ssl.SSLHandshakeException
            SslHandshakeError
          when Java::SunSecurityProviderCertpath::SunCertPathBuilderException
            # java.sun.security.provider.certpath.SunCertPathBuilderException
            SslCertificateChainError
          else
            self
          end
        error_class.new(root_cause)
      end

      def error_message
        'SSL error'
      end

      def format_message(root_cause)
        "#{error_message} [#{root_cause.message}]"
      end
    end

    #-----------------------------------------------------------------------------
    class SslCertificateExpiredError < SslException
      def error_message
        'SSL certificate expired'
      end

      def suggestion_message
        "Renew your SSL certificate or #{DISABLE_SSL}."
      end
    end

    #-----------------------------------------------------------------------------
    class SslCertificateNotYetValidError < SslException
      def error_message
        'SSL certificate is not yet valid'
      end

      def suggestion_message
        "Check your server clock, change your SSL certificate or #{DISABLE_SSL}."
      end
    end

    #-----------------------------------------------------------------------------
    class SslCertificateRevokedError < SslException
      def error_message
        'SSL certificate has been revoked'
      end

      def suggestion_message
        "Install a new SSL certificate or #{DISABLE_SSL}."
      end
    end

    #-----------------------------------------------------------------------------
    class SslHostNameError < SslException
      def error_message
        'SSL host name issue'
      end

      def suggestion_message
        "Make sure your domain name matches the SSL certificate name or #{DISABLE_SSL}."
      end
    end

    #-----------------------------------------------------------------------------
    class SslHandshakeError < SslException
      def error_message
        'SSL handshake error'
      end

      def suggestion_message
        'Upgrade your web server configuration (newer TLS version, secure ciphers, etc).'
      end
    end

    #-----------------------------------------------------------------------------
    class SslCertificateChainError < SslException
      def error_message
        'SSL certificate chain is invalid'
      end

      def suggestion_message
        <<~ERROR
          Make sure your SSL certificate chain is correct.
          For self-signed certificates or certificates signed with unknown
          certificate authorities, you can add your signing certificate to Enterprise Search
          Crawler configuration. Alternatively, you can #{DISABLE_SSL}.
        ERROR
      end
    end
  end
end
