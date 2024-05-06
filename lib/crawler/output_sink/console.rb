#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')

module Crawler
  module OutputSink
    class Console < OutputSink::Base
      def write(crawl_result)
        puts "# #{crawl_result.id}, #{crawl_result.url}, #{crawl_result.status_code}"

        if crawl_result.content_extractable_file?
          puts "** [Content extractable file (content type: #{crawl_result.content_type}, " \
               "content length: #{crawl_result.content.bytesize})] **"
        else
          puts crawl_result.content
        end

        success
      end
    end
  end
end
