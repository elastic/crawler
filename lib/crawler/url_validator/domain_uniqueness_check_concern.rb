#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module UrlValidator::DomainUniquenessCheckConcern # rubocop:disable Style/ClassAndModuleChildren
    extend ActiveSupport::Concern

    def validate_domain_uniqueness
      if crawler_api_config.domain_allowlist.include?(url.domain)
        validation_fail(:domain_uniqueness, 'Domain name already exists')
      else
        validation_ok(:domain_uniqueness, 'Domain name is new', domain: url.domain_name)
      end
    end
  end
end
