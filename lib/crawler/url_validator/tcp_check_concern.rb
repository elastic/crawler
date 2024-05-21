# frozen_string_literal: true

module Crawler::UrlValidator::TcpCheckConcern
  extend ActiveSupport::Concern

  def validate_tcp
    if proxy_configured?
      warning = 'TCP connection check could not be performed via an HTTP proxy.'
      return validation_warn(:tcp, warning)
    end

    host = url.host
    port = url.inferred_port
    details = { host:, port: }

    Socket.tcp(host, port, connect_timeout: Crawler::UrlValidator::TCP_CHECK_TIMEOUT) do
      validation_ok(:tcp, 'TCP connection successful', details)
    end
  rescue Errno::ETIMEDOUT
    validation_fail(:tcp, <<~EOF, details)
      TCP connection to #{host}:#{port} timed out. Please make sure the crawler
      instance is allowed to connect to your servers.
    EOF
  rescue SocketError, SystemCallError => e
    validation_fail(:tcp, "TCP connection to #{host}:#{port} failed: #{e}", details)
  end
end
