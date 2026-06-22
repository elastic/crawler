#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, '..', 'http_client')

module Crawler
  module HttpUtils
    class FilteringDnsResolver
      java_import java.net.InetSocketAddress
      java_import org.apache.hc.client5.http.DnsResolver
      java_import org.apache.hc.client5.http.SystemDefaultDnsResolver

      include DnsResolver

      attr_reader :default_resolver

      def initialize(loopback_allowed:, private_networks_allowed:, logger:)
        @default_resolver = SystemDefaultDnsResolver::INSTANCE
        @loopback_allowed = loopback_allowed
        @private_networks_allowed = private_networks_allowed
        @logger = logger
      end

      # Implements both overloads of the httpcore DnsResolver interface:
      #   * resolve(String)           -> InetAddress[]
      #   * resolve(String, int port) -> List<InetSocketAddress>
      # httpclient5 5.3+ invokes the two-argument variant from the connection
      # manager, so we must accept the optional port and return socket addresses
      # in that case while still applying our private-address filtering.
      def resolve(host, port = nil)
        resolved_addresses = default_resolver.resolve(host)
        filtered_addresses = remove_private_addresses(host, resolved_addresses)

        if port.nil?
          # resolve(String) must return an InetAddress[]
          filtered_addresses.to_java(java.net.InetAddress)
        else
          # resolve(String, int) must return a List<InetSocketAddress>
          socket_addresses = java.util.ArrayList.new
          filtered_addresses.each { |address| socket_addresses.add(InetSocketAddress.new(address, port)) }
          socket_addresses
        end
      end

      def resolve_canonical_hostname(host)
        default_resolver.resolve_canonical_hostname(host)
      end

      def loopback_allowed?
        !!@loopback_allowed
      end

      def private_networks_allowed?
        !!@private_networks_allowed
      end

      def remove_private_addresses(host, resolved_addresses)
        return resolved_addresses if resolved_addresses.blank?

        valid_addresses, invalid_addresses = resolved_addresses.partition do |a|
          allowed_address?(a)
        end

        if invalid_addresses.present?
          @logger.info("Rejected invalid addresses #{invalid_addresses.map(&:host_address)} for host #{host.inspect}")
        end

        if valid_addresses.empty?
          error = "Unable to request #{host.inspect} because it resolved to only private/invalid addresses"
          raise Crawler::HttpUtils::InvalidHost, error
        end

        valid_addresses
      end

      # Returns true if the given IP should be allowed during DNS resolution
      def allowed_address?(address)
        return false if address.is_loopback_address? && !loopback_allowed?
        return false if local_address?(address) && !private_networks_allowed?

        true
      end

      # Returns true if given IP address belongs to any of the networks considered private
      def local_address?(address)
        address.is_site_local_address?   || # RFC 1918 IP (10/8, 172.16/12, 192.168/16)
          address.is_link_local_address? || # link-local unicast in IPv4 (169.254.0.0/16)
          address.is_any_local_address?     # Wildcard IP address (0.0.0.0 in IPv4)
      end
    end
  end
end
