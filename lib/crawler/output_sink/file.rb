# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')

module Crawler
  class OutputSink::File < OutputSink::Base
    attr_reader :dir

    def initialize(*)
      super

      @dir = config.output_dir
      if !dir.is_a?(String) || dir.empty?
        raise ArgumentError, 'Missing or invalid output directory'
      end

      FileUtils.mkdir_p(dir)
    end

    def write(crawl_result)
      doc = to_doc(crawl_result)
      result_file = "#{dir}/#{crawl_result.url_hash}.json"
      File.write(result_file, doc.to_json)

      success
    end
  end
end
