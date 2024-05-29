#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

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
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml.feed(:xmlns => "http://www.w3.org/2005/Atom") {
            xml.title 'Faux Feed'
            @entries.each do |tags|
              xml.entry {
                tags.each do |tag|
                  if tag[:name] == 'content' # FIXME: Rewrite this as it makes me cry on the inside
                    xml.send(tag[:name], {:type => 'html'}, tag[:text])
                  elsif tag[:text] # generated from method_missing
                    xml.send(tag[:name], tag[:text])
                  else # generated from link_to
                    xml.send(tag[:name], tag.reject{|k, _| k == :name})
                  end
                end
              }
            end
          }
        end

        builder.to_xml.split("\n")
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
