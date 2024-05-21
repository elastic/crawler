# frozen_string_literal: true

module Crawler::UrlValidator::DomainAccessCheckConcern
  extend ActiveSupport::Concern

  def validate_domain_access
    if crawler_api_config.domain_allowlist.include?(url.domain)
      validation_ok(:domain_access, 'The URL matches one of the configured domains', domain: url.domain_name)
    else
      validation_fail(:domain_access, 'The URL does not match any configured domains')
    end
  end
end
