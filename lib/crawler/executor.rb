# frozen_string_literal: true

# An Executor fetches content by making requests described by CrawlTasks.
class Crawler::Executor
  def run(_crawl_task)
    raise NotImplementError
  end

  # Override to provide stats about the HTTP client
  def http_client_status
    raise NotImplementedError
  end
end
