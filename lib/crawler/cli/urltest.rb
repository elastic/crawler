# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

# I think the main idea should be for crawler to run a subset crawl
# - output of crawl result stdout or file ONLY (so ignore Elasticsearch output sink)
# - Grab the success/failure of the crawl
# - Explanation of any failures (blocked by crawl rules, 400 error, etc)

# What are the things we need to execute a crawl on a single URL?
# Do any user-set config settings need to be ignored/changed?
#   - Domains and seed URLs will have to be ignored because we will be testing a
#     specific URL endpoint against the rest of the config
#     - The endpoint is like a seed URL, as it is a base ULR + actual page to be crawled
#       thus we can treat the endpoint as a single seed URL
#   - We can try the following approaches
#     - clone and mod the config with only the given endpoint as a seed URL, run a crawl and gather info
#     - Figure out which 'components' of the crawling-end of Crawler we can individually call to only
#       crawl a single webpage

require 'dry/cli'
require 'yaml'

module Crawler
  module CLI
    class Urltest < Dry::CLI::Command
      desc 'Test a URL against a configuration'

      argument :crawl_config, required: true, desc: 'Path to crawl config file'

      argument :endpoint, required: true, desc: 'Endpoint to test'

      def call(crawl_config:, endpoint:, **)
        crawl_config = Crawler::CLI::Helpers.load_crawl_config(crawl_config, nil)
      end
    end
  end
end
