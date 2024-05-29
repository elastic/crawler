#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'stringio'
require 'nokogiri'
require 'zlib'

module Faux
  module Element
    class Sitemap < Base
      def call(env)
        @links = []
        super
      end

      def response_headers
        @headers.merge!({'Content-Type' => 'application/xml'})
        super
      end

      def link_to(url_or_path, options = {})
        if options[:relative]
          @links << url_or_path
        else
          @links << absolute_url_for(url_or_path)
        end
      end

      def response_body
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          if options[:index]
            xml.sitemapindex(:xmlns => "http://www.sitemaps.org/schemas/sitemap/0.9") {
              @links.each do |link|
                xml.sitemap {
                  xml.loc "#{link}"
                }
              end
            }
          else
            xml.urlset(:xmlns => "http://www.sitemaps.org/schemas/sitemap/0.9") {
              @links.each do |link|
                xml.url {
                  xml.loc "#{link}"
                }
              end
            }
          end
        end

        sitemap_txt = builder.to_xml

        if options[:gzip]
          [gzip(sitemap_txt)]
        else
          sitemap_txt.split("\n")
        end
      end

      def gzip(contents)
        file = StringIO.new
        file.set_encoding("BINARY")

        writer = Zlib::GzipWriter.new(file)
        writer.write(contents)
        writer.close

        file.string
      end
    end
  end
end
