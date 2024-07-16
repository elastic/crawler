#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Constants
  # Field names used in every crawl result when creating an ES doc
  RESERVED_FIELD_NAMES = %w[
    id
    body
    domains
    headings
    last_crawled_at
    links
    meta_description
    title
    url
    url_host
    url_path
    url_path_dir1
    url_path_dir2
    url_path_dir3
    url_port
    url_scheme
  ].freeze
end
