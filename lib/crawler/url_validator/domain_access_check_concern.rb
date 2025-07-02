#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module UrlValidator::DomainAccessCheckConcern # rubocop:disable Style/ClassAndModuleChildren
    extend ActiveSupport::Concern

    def validate_domain_access(_config)
      if crawler_api_config.domain_allowlist.include?(url.domain)
        validation_ok(:domain_access, 'The URL matches one of the configured domains', domain: url.domain_name)
      else
        validation_fail(:domain_access, 'The URL does not match any configured domains')
      end
    end
  end
end
