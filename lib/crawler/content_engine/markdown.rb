#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
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

        handle_start_tag(tag, node, markdown, list_type)

        # Process children
        list_type_for_children = %w[ul ol].include?(tag) ? tag.to_sym : list_type
        node.childNodes.each { |child| process_node(child, markdown, list_type_for_children) }

        handle_end_tag(tag, node, markdown)
      end

      START_TAG_MAPPING = {
        'h1' => "\n\n# ", 'h2' => "\n\n## ", 'h3' => "\n\n### ",
        'h4' => "\n\n#### ", 'h5' => "\n\n##### ", 'h6' => "\n\n###### ",
        'p' => "\n\n", 'br' => "\n", 'strong' => '**', 'b' => '**',
        'em' => '*', 'i' => '*', 'a' => '[', 'ul' => "\n", 'ol' => "\n",
        'code' => '`', 'pre' => "\n```\n"
      }.freeze

      END_TAG_MAPPING = {
        'h1' => "\n\n", 'h2' => "\n\n", 'h3' => "\n\n",
        'h4' => "\n\n", 'h5' => "\n\n", 'h6' => "\n\n", 'p' => "\n\n",
        'strong' => '**', 'b' => '**', 'em' => '*', 'i' => '*',
        'code' => '`', 'pre' => "\n```\n"
      }.freeze

      def self.handle_start_tag(tag, node, markdown, list_type)
        if START_TAG_MAPPING.key?(tag)
          markdown << START_TAG_MAPPING[tag]
        elsif tag == 'li'
          markdown << (list_type == :ol ? "\n1. " : "\n* ")
        elsif tag == 'img'
          markdown << "![#{node.attr('alt')}](#{node.attr('src')})"
        end
      end

      def self.handle_end_tag(tag, node, markdown)
        if END_TAG_MAPPING.key?(tag)
          markdown << END_TAG_MAPPING[tag]
        elsif tag == 'a'
          markdown << "](#{node.attr('href')})"
        end
      end
    end
  end
end
