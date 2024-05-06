#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'executor')

# MockExecutor returns pre-populated results for specified URIs.
module Crawler
  class MockExecutor < Crawler::Executor
    attr_reader :mock_results

    def initialize(mock_results = {}) # rubocop:disable Lint/MissingSuper
      @mock_results = mock_results # Hash of normalized URL strings to CrawlResponse objects.
    end

    def http_client_status
      {}
    end

    # The arg `follow_redirects` is required despite not being used within the method.
    # This is because the mock is called using expected args in specs.
    def run(crawl_task, follow_redirects: false) # rubocop:disable Lint/UnusedMethodArgument
      url = crawl_task.url
      mock_results.fetch(url.to_s, mock_404_result(url))
    end

    def mock_404_result(url)
      Crawler::Data::CrawlResult::Error.new(
        url: url,
        status_code: 404,
        error: 'Not found'
      )
    end
  end
end
