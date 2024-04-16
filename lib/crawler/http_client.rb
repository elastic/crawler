# frozen_string_literal: true

require 'weakref'

java_import java.util.LinkedHashMap
java_import java.security.KeyStore
java_import javax.net.ssl.SSLContext
java_import javax.net.ssl.TrustManagerFactory
java_import javax.net.ssl.X509TrustManager

java_import org.apache.commons.compress.compressors.brotli.BrotliCompressorInputStream

#---------------------------------------------------------------------------------------------------
class BrotliInputStreamFactory
  java_import org.apache.hc.client5.http.entity.InputStreamFactory
  include InputStreamFactory
  include Singleton

  def create(input_stream)
    BrotliCompressorInputStream.new(input_stream)
  end
end

module Crawler
  class HttpClient # rubocop:disable Metrics/ClassLength
    #
    # Please note: We cannot have these java_import calls at the top level
    # because it causes conflicts with Manticore's imports of httpclient v4.5
    #
    java_import org.apache.hc.client5.http.auth.AuthScope
    java_import org.apache.hc.client5.http.auth.UsernamePasswordCredentials

    java_import org.apache.hc.client5.http.classic.methods.HttpGet
    java_import org.apache.hc.client5.http.classic.methods.HttpHead
    java_import org.apache.hc.client5.http.config.RequestConfig
    java_import org.apache.hc.client5.http.entity.DeflateInputStreamFactory
    java_import org.apache.hc.client5.http.entity.GZIPInputStreamFactory

    java_import org.apache.hc.core5.http.io.SocketConfig
    java_import org.apache.hc.core5.http.HttpHost
    java_import org.apache.hc.core5.util.TimeValue

    java_import org.apache.hc.client5.http.ssl.DefaultHostnameVerifier
    java_import org.apache.hc.client5.http.ssl.NoopHostnameVerifier
    java_import org.apache.hc.client5.http.ssl.SSLConnectionSocketFactory

    java_import org.apache.hc.client5.http.impl.auth.BasicCredentialsProvider
    java_import org.apache.hc.client5.http.impl.classic.HttpClientBuilder
    java_import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManagerBuilder

    # Scoped this import to the class only to avoid conflicts with Ruby's Timeout module
    java_import org.apache.hc.core5.util.Timeout

    # The list of supported Content-Encoding methods to be used for each request
    CONTENT_DECODERS = LinkedHashMap.new.tap do |registry|
      registry.put('gzip', GZIPInputStreamFactory.instance)
      registry.put('x-gzip', GZIPInputStreamFactory.instance)
      registry.put('deflate', DeflateInputStreamFactory.instance)
      registry.put('br', BrotliInputStreamFactory.instance)
    end

    def initialize(options = {})
      @config = Crawler::HttpUtils::Config.new(options)
      @logger = config.fetch(:logger)

      @finalizers = []
      self.class.shutdown_on_finalize(self, finalizers)

      @connection_manager = new_connection_manager
      @client = new_http_client

      finalize(connection_manager, :shutdown)
      finalize(client, :close)
    end

    #-------------------------------------------------------------------------------------------------
    def head(url, headers: nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      raise ArgumentError, 'Need a Crawler URL object!' unless url.is_a?(Crawler::Data::URL)

      # Check to make sure connection pool is healthy before adding more requests to it
      check_connection_pool_stats!

      start_time = Time.now
      http_head = HttpHead.new(url.to_s)

      headers&.each do |key, value|
        http_head.set_header(key, value)
      end

      apache_response = client.execute(http_head)
      end_time = Time.now

      Crawler::HttpUtils::Response.new(
        apache_response: apache_response,
        url: url,
        request_start_time: start_time,
        request_end_time: end_time
      )
    rescue Java::JavaNet::SocketTimeoutException => e
      raise SocketTimeout, e
    rescue Java::OrgApacheHttpConn::ConnectTimeoutException => e
      raise ConnectTimeout, e
    rescue Java::JavaxNetSsl::SSLException => e
      raise SslException.for_java_error(e)
    rescue Java::OrgApacheHcCore5Http::NoHttpResponseException => e
      raise NoHttpResponseError.for_proxy_host(
        error: e,
        proxy_host: config.http_proxy_host
      )
    rescue Java::JavaLang::Exception => e
      raise BaseErrorFromJava, e
    end

    #-------------------------------------------------------------------------------------------------
    def get(url, headers: nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      raise ArgumentError, 'Need a Crawler URL object!' unless url.is_a?(Crawler::Data::URL)

      # Check to make sure connection pool is healthy before adding more requests to it
      check_connection_pool_stats!

      start_time = Time.now
      http_get = HttpGet.new(url.to_s)
      headers&.each do |key, value|
        http_get.set_header(key, value)
      end

      apache_response = client.execute(http_get)
      end_time = Time.now

      Crawler::HttpUtils::Response.new(
        apache_response: apache_response,
        url: url,
        request_start_time: start_time,
        request_end_time: end_time
      )
    rescue Java::JavaNet::SocketTimeoutException => e
      raise Crawler::HttpUtils::SocketTimeout, e
    rescue Java::OrgApacheHttpConn::ConnectTimeoutException => e
      raise Crawler::HttpUtils::ConnectTimeout, e
    rescue Java::JavaxNetSsl::SSLException => e
      raise Crawler::HttpUtils::SslException.for_java_error(e)
    rescue Java::OrgApacheHcCore5Http::NoHttpResponseException => e
      raise Crawler::HttpUtils::NoHttpResponseError.for_proxy_host(
        error: e,
        proxy_host: config.http_proxy_host
      )
    rescue Java::JavaLang::Exception => e
      raise Crawler::HttpUtils::BaseErrorFromJava, e
    end

    #-------------------------------------------------------------------------------------------------
    def connection_pool_stats
      connection_manager.total_stats
    end

    #-------------------------------------------------------------------------------------------------
    def self.shutdown_on_finalize(client, objs)
      ObjectSpace.define_finalizer(
        client,
        lambda do
          objs.each do |obj, args|
            obj.send(*args)
          rescue StandardError
            nil
          end
        end
      )
    end

    private

    attr_reader :config, :client, :connection_manager, :logger, :finalizers

    def new_http_client # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      builder = HttpClientBuilder.create
      builder.set_user_agent(config.user_agent)
      builder.disable_cookie_management
      builder.disable_connection_state
      builder.set_default_request_config(default_request_config)
      builder.set_default_credentials_provider(credentials_provider)
      builder.set_connection_manager(connection_manager)
      builder.disable_content_compression unless config.compression_enabled
      builder.set_content_decoder_registry(content_decoders)
      builder.set_proxy(proxy_host)
      builder.build
    end

    #-------------------------------------------------------------------------------------------------
    def content_decoders
      CONTENT_DECODERS
    end

    #-------------------------------------------------------------------------------------------------
    def new_connection_manager # rubocop:disable Metrics/AbcSize
      builder = PoolingHttpClientConnectionManagerBuilder.create
      builder.set_ssl_socket_factory(https_socket_factory)
      builder.set_dns_resolver(dns_resolver)
      builder.set_validate_after_inactivity(TimeValue.of_seconds(config.check_connection_timeout))
      builder.set_max_conn_per_route(config.pool_max_per_route)
      builder.set_max_conn_total(config.max_pool_size)
      builder.set_default_socket_config(default_socket_config)
      builder.build
    end

    #-------------------------------------------------------------------------------------------------
    def https_socket_factory
      # Initialize an SSL context using a relevant st of trust managers
      ssl_context = SSLContext.get_instance('TLS')
      ssl_context.init(nil, ssl_trust_managers, nil)

      # Get an SSL socket factory with our SSL context and host name verifier
      SSLConnectionSocketFactory.new(ssl_context, ssl_hostname_verifier)
    end

    #-------------------------------------------------------------------------------------------------
    def ssl_trust_managers # rubocop:disable Metrics/MethodLength
      if config.ssl_verification_mode == 'none'
        [Crawler::HttpUtils::AllTrustingTrustManager.new]
      else
        # Create a new trust store
        keystore = KeyStore.get_instance(KeyStore.default_type)
        keystore.load(nil, nil)

        # Add custom CA certs to the trust store (if needed)
        add_custom_ca_certificates(keystore)

        # Add all of the default system root CA certs into the keystore
        add_default_root_certificates(keystore)

        # Set up a new trust manager and use the new trust store
        tmf = TrustManagerFactory.get_instance(TrustManagerFactory.default_algorithm)
        tmf.init(keystore)

        # Returns the new trust managers list
        tmf.trust_managers
      end
    end

    #-------------------------------------------------------------------------------------------------
    # Adds all configured custom CA certificates to the given keystore
    # Certificates could be specified as file names or as PEM-formatted strings
    def add_custom_ca_certificates(keystore)
      config.ssl_ca_certificates.each_with_index do |cert, index|
        keystore.setCertificateEntry("custom_ca_#{index}", cert)
      end
    end

    #-------------------------------------------------------------------------------------------------
    # Loads default Root CA certificates into the given keystore
    # Generally, the certs are loaded from JAVA_HOME/lib/cacerts
    def add_default_root_certificates(keystore)
      tmf = TrustManagerFactory.get_instance(TrustManagerFactory.default_algorithm)
      # There are multiple implementations of the init method, pick a specific one
      # since only that one accepts a null argument to obtain the default keystore
      init = tmf.java_method(:init, [KeyStore])
      init.call(nil)

      # Copy all registered CA certificates into our new keystore
      tmf.trust_managers.each do |tm|
        next unless tm.is_a?(X509TrustManager)

        tm.accepted_issuers.each do |cert|
          keystore.set_certificate_entry(cert.subject_dn.name, cert)
        end
      end
    end

    #-------------------------------------------------------------------------------------------------
    # Returns an SSL hostname verifier instance based on our configuration
    def ssl_hostname_verifier
      case config.ssl_verification_mode
      when 'full'
        DefaultHostnameVerifier.new
      when 'certificate', 'none'
        NoopHostnameVerifier.new
      else
        raise ArgumentError, "Invalid SSL verification mode: #{config.ssl_verification_mode}"
      end
    end

    #-------------------------------------------------------------------------------------------------
    # Returns our custom DNS resolver to be used for all connections
    def dns_resolver
      Crawler::HttpUtils::FilteringDnsResolver.new(
        loopback_allowed: config.loopback_allowed?,
        private_networks_allowed: config.private_networks_allowed?,
        logger: logger
      )
    end

    #-------------------------------------------------------------------------------------------------
    # Returns a socket config to be used for all connections
    def default_socket_config
      builder = SocketConfig.custom
      builder.set_so_timeout(Timeout.of_seconds(config.socket_timeout))
      builder.build
    end

    #-------------------------------------------------------------------------------------------------
    # Returns a request config to be used for all connections
    def default_request_config
      builder = RequestConfig.custom
      builder.set_connection_request_timeout(Timeout.of_seconds(config.connection_request_timeout))
      builder.set_connect_timeout(Timeout.of_seconds(config.connect_timeout))
      builder.set_response_timeout(Timeout.of_seconds(config.socket_timeout))
      builder.set_redirects_enabled(false)
      builder.build
    end

    #-------------------------------------------------------------------------------------------------
    # Returns a proxy host object to be used for all connections
    def proxy_host # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return nil unless config.http_proxy_host

      logger.debug(<<~LOG.squish)
        Proxy configuration:
        scheme=#{config.http_proxy_scheme},
        host=#{config.http_proxy_host},
        port=#{config.http_proxy_port}
      LOG

      HttpHost.new(
        config.http_proxy_scheme,
        config.http_proxy_host,
        config.http_proxy_port
      )
    end

    #-------------------------------------------------------------------------------------------------
    # Returns a credentials provider to be used for all requests
    # By default, it will be empty and not have any credentials in it
    def credentials_provider
      BasicCredentialsProvider.new.tap do |provider|
        next unless config.http_proxy_host && proxy_credentials

        logger.debug('Enabling proxy auth!')
        proxy_auth_scope = AuthScope.new(proxy_host)
        provider.set_credentials(proxy_auth_scope, proxy_credentials)
      end
    end

    #-------------------------------------------------------------------------------------------------
    # Returns HTTP credentials to be used for proxy requests
    def proxy_credentials
      return unless config.http_proxy_username && config.http_proxy_password

      UsernamePasswordCredentials.new(
        config.http_proxy_username,
        config.http_proxy_password.to_java_string.to_char_array
      )
    end

    #-------------------------------------------------------------------------------------------------
    # Checks the status of the connection pool and logs information about it
    def check_connection_pool_stats! # rubocop:disable Metrics/MethodLength
      stats = connection_pool_stats
      used_connections = stats.leased + stats.available

      if used_connections >= stats.max
        logger.error(<<~LOG.squish)
          HTTP client connection pool is full!
          If the issue persists, it may be an indication of an issue with the remote server
          or a problem with the crawler. Current pool status: #{stats}
        LOG
      elsif used_connections >= stats.max * 0.9
        logger.warn(<<~LOG.squish)
          HTTP client connection pool is 90% full!
          If we hit the 100% utilization, the crawler will not be able to request any more pages
          from the remote server. This may be an indication of an issue with the remote server
          or a problem with the crawler. Current pool status: #{stats}
        LOG
      else
        logger.debug("Connection pool stats: #{stats}")
      end
    end

    #-------------------------------------------------------------------------------------------------
    def finalize(object, args)
      finalizers << [WeakRef.new(object), Array(args)]
    end
  end
end

require_dependency File.join(__dir__, 'http_utils', 'exceptions')
require_dependency File.join(__dir__, 'http_utils', 'config')
require_dependency File.join(__dir__, 'http_utils', 'response')
require_dependency File.join(__dir__, 'http_utils', 'filtering_dns_resolver')
require_dependency File.join(__dir__, 'http_utils', 'all_trusting_trust_manager')
