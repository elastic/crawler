#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module UrlValidator::UrlCheckConcern # rubocop:disable Style/ClassAndModuleChildren
    extend ActiveSupport::Concern

    def validate_url(_config) # rubocop:disable Metrics/AbcSize
      if url.scheme.blank?
        validation_fail(:url, 'URL scheme is missing. Domain URLs must start with https:// or http://')
      elsif !url.supported_scheme?
        validation_fail(:url, "Unsupported URL scheme: #{url.scheme}", scheme: url.scheme)
      elsif url.path.present? && !configuration
        validation_fail(:url, 'Domain URLs cannot contain a path')
      else
        validation_ok(:url, 'URL structure looks valid')
      end
    rescue Addressable::URI::InvalidURIError => e
      validation_fail(:url, "Error parsing domain name: #{e}")
    end
  end
end
