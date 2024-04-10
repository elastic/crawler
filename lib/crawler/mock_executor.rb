# frozen_string_literal: true

require_dependency File.join(__dir__, 'executor')

# MockExecutor returns pre-populated results for specified URIs.
module Crawler
  class MockExecutor < Crawler::Executor
    attr_reader :mock_results

    def initialize(mock_results = {})
      @mock_results = mock_results # Hash of normalized URL strings to CrawlResponse objects.
    end

    def http_client_status
      {}
    end

    def run(crawl_task, follow_redirects: false)
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
