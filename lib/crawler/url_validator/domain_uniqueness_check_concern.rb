# frozen_string_literal: true

module Crawler::UrlValidator::DomainUniquenessCheckConcern
  extend ActiveSupport::Concern

  def validate_domain_uniqueness
    if crawler_api_config.domain_allowlist.include?(url.domain)
      validation_fail(:domain_uniqueness, 'Domain name already exists')
    else
      validation_ok(:domain_uniqueness, 'Domain name is new', domain: url.domain_name)
    end
  end
end
