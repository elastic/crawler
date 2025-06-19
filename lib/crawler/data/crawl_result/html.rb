#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency(File.join(__dir__, 'success'))
require_dependency(File.join(__dir__, '..', '..', '..', 'constants'))

java_import org.jsoup.nodes.TextNode

module Crawler
  module Data
    module CrawlResult
      class HTML < Success
        # Allow constructor to be called on concrete result classes
        public_class_method :new

        def initialize(status_code: 200, **kwargs)
          super
        end

        def parsed_content
          @parsed_content ||= Jsoup.parse(content)
        end

        def to_s
          "<CrawlResult::HTML: id=#{id}, status_code=#{status_code}, url=#{url}, content=#{content.bytesize} bytes>"
        end

        def to_h
          super.tap do |h|
            h[:content] = content
          end
        end

        # Returns the base URL that should be used for all relative links
        def base_url
          @base_url ||= begin
            # Check if there is a <base> tag with a href attribute we should be using
            base_href = extract_attribute_value('base[href]', 'href').to_s.strip
            if base_href.present?
              base_url = begin
                parsed_url = Crawler::Data::URL.parse(base_href)
                # parsed URL can be relative as well, complete with current URL if needed
                parsed_url.site ||= url.site
                parsed_url
              rescue Addressable::URI::InvalidURIError
                nil
              end
            end

            # Fall back to the default base URL for the page
            base_url || url
          end
        end

        # Returns all links from the document as a set of URL objects
        def extract_links(limit: nil, skip_invalid: false)
          links = Set.new
          limit_reached = false

          parsed_content.select('a[href]').each do |a|
            # Parse the link
            link = Link.new(base_url:, node: a)

            # Optionally skip invalid links
            next if skip_invalid && !link.valid?

            links << link

            if limit && links.count >= limit
              limit_reached = true
              break
            end
          end

          { links:, limit_reached: }
        end

        # Returns an array of links extracted from the page, up to a specified limit of items
        def links(limit: 10)
          # Get a set of valid links
          result = extract_links(limit:, skip_invalid: true)
          links = result.fetch(:links)

          # Convert them to an array of strings with a predictable order
          links.to_a.map(&:to_url).map(&:to_s).sort
        end

        # Returns the canonical URL of the document
        def canonical_url
          canonical_link&.to_url
        end

        # Returns the canonical URL of the document as a link object
        def canonical_link
          link_href = extract_attribute_value('link[rel=canonical]', 'href')
          return if link_href.blank?

          Link.new(base_url: url, link: link_href)
        end

        # Returns +true+ if the page contains a robots nofollow meta tag
        def meta_nofollow?
          !!parsed_content.selectFirst('meta[name=robots][content*=nofollow]')
        end

        # Returns +true+ if the page contains a robots noindex meta tag
        def meta_noindex?
          !!parsed_content.selectFirst('meta[name=robots][content*=noindex]')
        end

        # Returns the meta tag value for keywords
        def meta_keywords(limit: 512)
          keywords = extract_attribute_value('meta[name=keywords]', 'content')
          Crawler::ContentEngine::Utils.limit_bytesize(keywords, limit)
        end

        # Returns the meta tag value for the description of the page
        def meta_description(limit: 1024)
          description = extract_attribute_value('meta[name=description]', 'content')
          Crawler::ContentEngine::Utils.limit_bytesize(description, limit)
        end

        def meta_tags_elastic(limit: 512)
          meta_elastic_class = 'elastic'
          meta_tag_selector = "meta.#{meta_elastic_class}"

          # filter by the meta_tag_selector first to only get meta tags with class='elastic'
          extractions = {}
          parsed_content.select(meta_tag_selector).select('meta[name][content]').each do |meta|
            # truncate the content field of each tag we extract
            truncated_content = Crawler::ContentEngine::Utils.limit_bytesize(meta.attr('content'), limit)
            extractions[meta.attr('name')] = truncated_content if valid_field_name?(meta.attr('name'))
          end
          extractions
        end

        def data_attributes_from_body(limit: 512)
          data_elastic_name = 'data-elastic-name'
          body_embedded_tag_selector = "[#{data_elastic_name}]"

          extractions = {}
          parsed_content.body.select(body_embedded_tag_selector).each do |data|
            truncated_content = Crawler::ContentEngine::Utils.limit_bytesize(
              data.text.to_s.squish,
              limit
            )
            if valid_field_name?(data.attr(data_elastic_name))
              extractions[data.attr(data_elastic_name)] =
                truncated_content
            end
          end
          extractions
        end

        def valid_field_name?(field_name)
          # Meta tag field names are subject to field name rules
          # - Must contain a lowercase letter and may only contain lowercase letters, numbers, and underscores.
          # - Must not contain whitespace or have a leading underscore.
          # - Must not contain more than 64 characters
          # - Must not be a reserved word (see lib/constants.rb)
          # Method returns true if the field name is valid
          character_validation = field_name.match?(/\A[a-z0-9_]+\z/) &&
                                 !field_name.start_with?('_') &&
                                 field_name.length <= 64

          true unless character_validation == false || Constants::RESERVED_FIELD_NAMES.include?(field_name) == true
        end

        # Returns the title of the document, cleaned up for indexing
        def document_title(limit: 1000)
          title_tag = parsed_content.selectFirst('title')
          title = Crawler::ContentEngine::Utils.node_descendant_text(title_tag)
          Crawler::ContentEngine::Utils.limit_bytesize(title, limit)
        end

        # Returns the body of the document, cleaned up for indexing
        def document_body(limit: 5.megabytes)
          body_tag = parsed_content.body
          return '' unless body_tag

          body_tag = Crawler::ContentEngine::Transformer.transform(body_tag)
          body_content = Crawler::ContentEngine::Utils.node_descendant_text(body_tag)
          Crawler::ContentEngine::Utils.limit_bytesize(body_content, limit)
        end

        # Returns an array of section headings from the page (using h1-h6 tags to find those)
        def headings(limit: 10)
          body_tag = parsed_content.body
          return [] unless body_tag

          Set.new.tap do |headings|
            body_tag.select('h1, h2, h3, h4, h5, h6').each do |heading|
              heading = heading.text.to_s.squish
              next if heading.empty?

              headings << heading
              break if headings.count >= limit
            end
          end.to_a
        end

        def extract_attribute_value(tag_name, attribute_name)
          parsed_content.select(tag_name)&.attr(attribute_name)
        end

        # Lookup for content using CSS selector
        #
        # @param [String] selector - CSS selector
        # @return [Array<String>]
        def extract_by_css_selector(selector, ignore_tags)
          parsed_content.select(selector).map do |node|
            Crawler::ContentEngine::Utils.node_descendant_text(node, ignore_tags)
          end
        end

        # Lookup for content using XPath selector
        #
        # @param [String] selector - XPath selector
        # @return [Array<String>]
        def extract_by_xpath_selector(selector, ignore_tags)
          # jsoup xpath selector requires the target node to be included as a second argument
          # here we assume that users are only interested in text nodes, which is the actual
          # raw text inside an HTML element.
          parsed_content.selectXpath(selector, TextNode.java_class).map do |node|
            Crawler::ContentEngine::Utils.node_descendant_text(node, ignore_tags)
          end
        end

        def full_html(enabled: false)
          return unless enabled

          parsed_content.body.html
        end
      end
    end
  end
end
