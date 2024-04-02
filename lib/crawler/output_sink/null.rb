# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')

module Crawler
  class OutputSink::Null < OutputSink::Base
    def write(_)
      # Discard the results
    end
  end
end
