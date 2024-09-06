#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')

module Crawler
  module OutputSink
    class File < OutputSink::Base
      attr_reader :dir

      def initialize(*)
        super

        @dir = config.output_dir
        raise ArgumentError, 'Missing or invalid output directory' if !dir.is_a?(String) || dir.empty?

        FileUtils.mkdir_p(dir)
      end

      def write(crawl_result)
        doc = to_doc(crawl_result)
        result_file = "#{dir}/#{crawl_result.url_hash}.json"
        ::File.write(result_file, doc.to_json)

        success
      end
    end
  end
end
