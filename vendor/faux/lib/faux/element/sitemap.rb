#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'stringio'
require 'rexml/document'
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
        doc = REXML::Document.new
        doc << REXML::XMLDecl.new('1.0', 'UTF-8')
        doc.context[:attribute_quote] = :quote
        if options[:index]
          root = doc.add_element('sitemapindex', 'xmlns' => 'http://www.sitemaps.org/schemas/sitemap/0.9')
          item = 'sitemap'
        else
          root = doc.add_element('urlset', 'xmlns' => 'http://www.sitemaps.org/schemas/sitemap/0.9')
          item = 'url'
        end
        @links.each do |link|
          root.add_element(item).add_element('loc').text = link.to_s
        end

        sitemap_txt = +''
        doc.write(output: sitemap_txt, indent: 2)

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
