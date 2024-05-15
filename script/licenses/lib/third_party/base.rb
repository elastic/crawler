#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'httpclient'

module ThirdParty
  class Base
    class << self
      def get(*args)
        new.get(*args)
      end
    end

    def type
      raise 'implement in subclass'
    end

    def licenses_path
      raise 'implement in subclass'
    end

    def license_fallbacks
      raise 'implement in subclass'
    end

    def license_file_fallbacks
      raise 'implement in subclass'
    end

    def get(*)
      raise 'implement in subclass'
    end

    def spdx_license_for_dependency(identifier, licenses)
      spdx_licenses = licenses.filter_map { |license| SPDX.normalize_license(license) }

      logger.info("Ruby Gem #{identifier} using SPDX license.")
      spdx_license = find_spdx_license(identifier, licenses.size, spdx_licenses)

      unless spdx_license
        logger.warn("#{type} #{identifier} has no SPDX license identifier. Original licenses: #{licenses.inspect}")
      end

      spdx_license
    end

    def license_file_path_for_dependency(identifier)
      unless license_file_fallbacks.key?(identifier)
        logger.error("#{type} #{identifier} has no license file.")
        exit(2)
      end

      override = license_file_fallbacks.fetch(identifier)
      add_license_to_path(identifier, override)
    end

    def format_library_for_notice_txt(_identifier, dependency)
      "#{dependency[:name]} #{dependency[:version]}"
    end

    private

    def find_spdx_license(identifier, total_licenses, spdx_licenses)
      if spdx_licenses.any? && spdx_licenses.size == total_licenses
        spdx_licenses.join(' OR ')
      elsif license_fallbacks.key?(identifier)
        license_fallbacks.fetch(identifier)
      end
    end

    def add_license_to_path(identifier, override)
      identifier_in_filename = identifier.gsub('/', '--')

      if override[:manually_added]
        logger.info("#{type} #{identifier} using manually added file.")
        licenses_path.join("_manually_added_#{identifier_in_filename}-LICENSE.txt").to_s
      elsif override[:url]
        download_license_file(identifier, identifier_in_filename, override)
      end
    end

    def download_license_file(identifier, identifier_in_filename, override)
      licenses_path.join("_downloaded_#{identifier_in_filename}-LICENSE.txt").to_s.tap do |license_file_path|
        logger.info("#{type} #{identifier} downloading license from #{override[:url]}")
        content = HTTPClient.get_content(override[:url])
        File.write(license_file_path, content)
      end
    end

    def logger
      LOGGER
    end
  end
end
