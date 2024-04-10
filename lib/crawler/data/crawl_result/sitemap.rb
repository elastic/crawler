# frozen_string_literal: true

require 'stringio'
require 'zlib'

require_dependency(File.join(__dir__, 'success'))

module Crawler
  module Data
    module CrawlResult
      class Sitemap < Success
        # Allow constructor to be called on concrete result classes
        public_class_method :new

        #---------------------------------------------------------------------------------------------
        # Returns links from a sitemap document as a set of URL objects
        def extract_links
          { limit_reached: false, links: { content: [], sitemap: [] } }.tap do |results|
            if sitemap.index?
              results[:links][:sitemap] = coerce_to_links(sitemap.sitemaps)
            else
              results[:links][:content] = coerce_to_links(sitemap.site_map_urls)
            end
          rescue Java::CrawlercommonsSitemaps::UnknownFormatException => e
            results[:error] = "Failed to parse sitemap: #{e}"
          end
        end

        #---------------------------------------------------------------------------------------------
        def coerce_to_links(sitemap_urls)
          sitemap_urls.map do |sitemap_url|
            # NOTE: We use the root of the site as the base, not the sitemap URL itself
            Link.new(
              base_url: site_url,
              link: sitemap_url.url.to_s
            )
          end
        end

        #---------------------------------------------------------------------------------------------
        # Returns a sitemap parser to be used for extracting links, etc from the crawl result
        def sitemap_parser
          @sitemap_parser ||= begin
            strict_parser = false
            allow_partial = true
            Java::CrawlercommonsSitemaps::SiteMapParser.new(strict_parser, allow_partial)
          end
        end

        # Returns a parsed version of the sitemap or raises an error if the sitemap is broken
        def sitemap
          @sitemap ||= begin
            content_as_bytes = xml_content.unpack('c*').to_java(:byte)
            sitemap_parser.parse_site_map(content_as_bytes, url.java_url)
          end
        end

        private

        def xml_content
          Zlib::GzipReader.new(StringIO.new(content)).read
        rescue Zlib::GzipFile::Error
          content
        end
      end
    end
  end
end
