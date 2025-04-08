# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'dry/cli'
require 'yaml'

module Crawler
  module CLI
    class Urltest < Dry::CLI::Command
      desc 'Test a URL against a configuration'

      argument :crawl_config, required: true, desc: 'Path to crawl config file'

      argument :endpoint, required: true, desc: 'Endpoint to test'

      def call(crawl_config:, endpoint:, **)
        # crawl_single_url_simple(crawl_config, endpoint)
        crawl_single_url(crawl_config, endpoint)
      end

      def crawl_single_url(crawl_config, endpoint)
        config = Crawler::CLI::Helpers.load_crawl_config(crawl_config, nil)
        crawl = Crawler::API::Crawl.new(config)

        crawl.start_urltest_crawl!(endpoint)
      end
    end
  end
end
