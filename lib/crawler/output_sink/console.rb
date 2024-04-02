# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')

module Crawler
  class OutputSink::Console < OutputSink::Base
    def write(crawl_result)
      puts "# #{crawl_result.id}, #{crawl_result.url}, #{crawl_result.status_code}"

      if crawl_result.content_extractable_file?
        puts "** [Content extractable file (content type: #{crawl_result.content_type}, content length: #{crawl_result.content.bytesize})] **"
      else
        puts crawl_result.content
      end

      success
    end
  end
end
