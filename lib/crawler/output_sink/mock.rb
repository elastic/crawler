#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')

module Crawler
  module OutputSink
    class Mock < OutputSink::Base
      attr_reader :results

      def initialize(*)
        super

        @results = config.results_collection
        raise ArgumentError, 'Needs a ResultsCollection' unless results.is_a?(ResultsCollection)
      end

      def write(crawl_result)
        results.append(crawl_result)

        success
      end
    end
  end
end
