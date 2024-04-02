# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')

module Crawler
  class OutputSink::Mock < OutputSink::Base
    attr_reader :results

    def initialize(*)
      super

      @results = config.results_collection
      unless results.kind_of?(ResultsCollection)
        raise ArgumentError, 'Needs a ResultsCollection'
      end
    end

    def write(crawl_result)
      results.append(crawl_result)

      success
    end
  end
end
