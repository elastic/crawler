#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'rexml/document'

module Faux
  module Element
    class AtomFeed < Base
      def call(env)
        @entries = []
        super
      end

      def response_headers
        @headers.merge!({'Content-Type' => 'text/xml'})
        super
      end

      def response_body
        doc = REXML::Document.new
        doc << REXML::XMLDecl.new('1.0', 'UTF-8')
        doc.context[:attribute_quote] = :quote
        feed = doc.add_element('feed', 'xmlns' => 'http://www.w3.org/2005/Atom')
        feed.add_element('title').text = 'Faux Feed'
        @entries.each do |tags|
          entry = feed.add_element('entry')
          tags.each do |tag|
            if tag[:name] == 'content' # FIXME: Rewrite this as it makes me cry on the inside
              element = entry.add_element('content', 'type' => 'html')
              element.text = tag[:text]
            elsif tag[:text] # generated from method_missing
              entry.add_element(tag[:name].to_s).text = tag[:text]
            else # generated from link_to
              attrs = tag.reject { |k, _| k == :name }.map { |k, v| [k.to_s, v.to_s] }.to_h
              entry.add_element(tag[:name].to_s, attrs)
            end
          end
        end

        out = +''
        doc.write(output: out, indent: 2)
        out.split("\n")
      end

      def entry(&block)
        @tags = [] # Holds hashes with tags defined inside &block
        block.call
        @entries << @tags
      end

      def link_to(url, rel='self')
        @tags << {:name => :link, :href => absolute_url_for(url), :rel => rel}
      end

      def html_content(html)
        @tags << {:name => 'content', :text => html}
      end

      def method_missing(method, *args, &block)
        @tags << {:name => method, :text => args[0]}
      end
    end
  end
end
