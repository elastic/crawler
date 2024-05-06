#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

# An Executor fetches content by making requests described by CrawlTasks.
module Crawler
  class Executor
    def run(_crawl_task)
      raise NotImplementError
    end

    # Override to provide stats about the HTTP client
    def http_client_status
      raise NotImplementedError
    end
  end
end
