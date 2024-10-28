#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module ContentEngine
    module Transformer
      INCLUDE_ATTR = 'data-elastic-include'
      EXCLUDE_ATTR = 'data-elastic-exclude'
      EXCLUDE_ATTR_SELECTOR = "[#{EXCLUDE_ATTR}]".freeze

      def self.transform(tag)
        transform!(tag.dup)
      end

      def self.transform!(tag)
        loop do
          node = tag.hasAttr(EXCLUDE_ATTR) ? tag : tag.selectFirst(EXCLUDE_ATTR_SELECTOR)
          break if node.nil?

          traverse!(node, mode: :exclude)
        end

        tag
      end

      def self.traverse!(node, mode:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        # The exclusion attribute is used to determine what to traverse next in the parent loop,
        # so we should remove the attribute while traversing to avoid an infinite loop.
        node.removeAttr(EXCLUDE_ATTR) if node.hasAttr(EXCLUDE_ATTR)

        node.childNodes.each do |child_node|
          if child_node.is_a?(Java::OrgJsoupNodes::TextNode) && mode == :exclude
            child_node.remove
          elsif child_node.is_a?(Java::OrgJsoupNodes::Element)
            new_mode =
              if child_node.hasAttr(INCLUDE_ATTR)
                :include
              elsif child_node.hasAttr(EXCLUDE_ATTR)
                :exclude
              else
                mode # mode is unchanged
              end

            traverse!(child_node, mode: new_mode)
          end
        end
      end
    end
  end
end
