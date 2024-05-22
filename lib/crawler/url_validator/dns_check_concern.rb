#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'resolv'

module Crawler
  module UrlValidator::DnsCheckConcern # rubocop:disable Style/ClassAndModuleChildren
    extend ActiveSupport::Concern

    def validate_dns
      if proxy_configured?
        warning = 'DNS resolution check could not be performed via an HTTP proxy.'
        return validation_warn(:dns, warning)
      end

      # Prepare DNS resolvers
      resolv = Resolv.new([
                            Resolv::Hosts.new,
                            Resolv::DNS.new.tap do |dns|
                              dns.timeouts = Crawler::UrlValidator::DNS_CHECK_TIMEOUT
                            end
                          ])

      # Check DNS
      addresses = resolv.getaddresses(url.host)

      if addresses.empty?
        validation_fail(:dns, 'DNS name resolution failed. No suitable addresses found!')
      else
        validation_ok(:dns, "Domain name resolution successful: #{addresses.count} addresses found",
                      addresses:)
      end
    rescue Resolv::ResolvError, ArgumentError => e
      validation_fail(:dns, <<~MESSAGE)
        DNS resolution failure: #{e}. Please check the spelling of your domain
        or your DNS configuration.
      MESSAGE
    end
  end
end
