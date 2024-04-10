# frozen_string_literal: true

require_dependency File.join(__dir__, '..', 'http_client')

module Crawler
  module HttpClient
    class FilteringDnsResolver
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

      def resolve(host)
        resolved_addresses = default_resolver.resolve(host)
        remove_private_addresses(host, resolved_addresses)
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
          raise Crawler::HttpClient::InvalidHost, error
        end

        valid_addresses
      end

      # Returns true if the given IP should be allowed during DNS resolution
      def allowed_address?(a)
        return false if a.is_loopback_address? && !loopback_allowed?
        return false if local_address?(a) && !private_networks_allowed?

        true
      end

      # Returns true if given IP address belongs to any of the networks considered private
      def local_address?(a)
        a.is_site_local_address?   || # RFC 1918 IP (10/8, 172.16/12, 192.168/16)
          a.is_link_local_address? || # link-local unicast in IPv4 (169.254.0.0/16)
          a.is_any_local_address?     # Wildcard IP address (0.0.0.0 in IPv4)
      end
    end
  end
end
