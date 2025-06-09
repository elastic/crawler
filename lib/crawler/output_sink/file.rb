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

      def generate_filename_from_url(crawl_result)
        full_url = crawl_result.url.to_s
        full_url = full_url.chop if full_url.end_with?('/') # trim tailing slash if present

        filename = full_url
                   .gsub(/[^a-zA-Z0-9\-_]/, '_') # replace slashes with underscores
                   .squeeze('_') # remove repetitive underscores
                   .gsub(/^https?_?(www_)?/, '') # remove scheme and www

        # Most OSes limit filenames to 256 chars, we should truncate if too long
        if filename.length > 255
          # 128 + 122 = 250 chars, leaving 6 chars for the file extension (.json)
          starting_idx = 128
          ending_idx = filename.length - 122
          # slice out the middle to retain the domain and more unique paths at the end of the URL
          filename.slice!(starting_idx..ending_idx)
        end

        filename
      end

      def write(crawl_result)
        doc = to_doc(crawl_result)
        document_filename = "#{generate_filename_from_url(crawl_result)}.json"
        system_logger.debug("Writing crawled document to #{dir}/#{document_filename}")
        result_file = "#{dir}/#{document_filename}"
        ::File.write(result_file, doc.to_json)

        success
      end
    end
  end
end
