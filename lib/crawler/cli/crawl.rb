#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'dry/cli'
require 'yaml'

module Crawler
  module CLI
    class Crawl < Dry::CLI::Command
      desc 'Run a crawl of the site'

      argument :crawl_config, required: true, desc: 'Path to crawl config file'

      option :es_config, desc: 'Path to elasticsearch config file'

      def call(crawl_config:, es_config: nil, **)
        crawl_config = Crawler::CLI::Helpers.load_crawl_config(crawl_config, es_config)
        crawl = Crawler::API::Crawl.new(crawl_config)

        crawl.start!
      end
    end
  end
end
