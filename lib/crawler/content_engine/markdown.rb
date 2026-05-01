#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

#
# This file was created by gemini-cli to implement Markdown reformatting.
#

# frozen_string_literal: true

module Crawler
  module ContentEngine
    module Markdown
      java_import org.jsoup.nodes.TextNode
      java_import org.jsoup.nodes.Element

      # Convert a Jsoup HTML node to Markdown
      def self.convert(node)
        return '' unless node

        markdown = []
        process_node(node, markdown)
        markdown.join.gsub(/\n{3,}/, "\n\n").strip
      end

      def self.process_node(node, markdown, list_type = nil)
        if node.is_a?(TextNode)
          text = node.text
          markdown << text if text && !text.empty?
          return
        end

        return unless node.is_a?(Element)

        tag = node.tagName.downcase
        return if Crawler::ContentEngine::Utils::NON_CONTENT_TAGS.include?(tag)

        # Handle start of tags
        case tag
        when 'h1' then markdown << "\n\n# "
        when 'h2' then markdown << "\n\n## "
        when 'h3' then markdown << "\n\n### "
        when 'h4' then markdown << "\n\n#### "
        when 'h5' then markdown << "\n\n##### "
        when 'h6' then markdown << "\n\n###### "
        when 'p' then markdown << "\n\n"
        when 'br' then markdown << "\n"
        when 'strong', 'b' then markdown << "**"
        when 'em', 'i' then markdown << "*"
        when 'a' then markdown << "["
        when 'ul'
          markdown << "\n"
          list_type = :ul
        when 'ol'
          markdown << "\n"
          list_type = :ol
        when 'li'
          markdown << (list_type == :ol ? "\n1. " : "\n* ")
        when 'code' then markdown << "`"
        when 'pre' then markdown << "\n```\n"
        when 'img'
          alt = node.attr('alt')
          src = node.attr('src')
          markdown << "![#{alt}](#{src})"
        end

        # Process children
        node.childNodes.each { |child| process_node(child, markdown, list_type) }

        # Handle end of tags
        case tag
        when 'h1', 'h2', 'h3', 'h4', 'h5', 'h6' then markdown << "\n\n"
        when 'p' then markdown << "\n\n"
        when 'strong', 'b' then markdown << "**"
        when 'em', 'i' then markdown << "*"
        when 'a'
          href = node.attr('href')
          markdown << "](#{href})"
        when 'code' then markdown << "`"
        when 'pre' then markdown << "\n```\n"
        end
      end
    end
  end
end
