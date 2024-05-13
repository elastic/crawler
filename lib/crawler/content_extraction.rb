#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module ContentExtraction
    INCLUDE_ATTR = 'data-elastic-include'
    EXCLUDE_ATTR = 'data-elastic-exclude'
    EXCLUDE_ATTR_SELECTOR = "[#{EXCLUDE_ATTR}]".freeze

    def self.transform(doc)
      transform!(doc.dup)
    end

    def self.transform!(doc)
      loop do
        node = doc.has_attribute?(EXCLUDE_ATTR) ? doc : doc.at_css(EXCLUDE_ATTR_SELECTOR)
        break unless node

        traverse!(node, mode: :exclude)
      end

      doc
    end

    def self.traverse!(node, mode:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      # The exclusion attribute is used to determine what to traverse next in the parent loop,
      # so we should remove the attribute while traversing to avoid an infinite loop.
      node.remove_attribute(EXCLUDE_ATTR) if node.has_attribute?(EXCLUDE_ATTR)

      node.children.each do |child_node|
        if child_node.text? && mode == :exclude
          child_node.unlink
        elsif child_node.element?
          new_mode =
            if child_node.has_attribute?(INCLUDE_ATTR)
              :include
            elsif child_node.has_attribute?(EXCLUDE_ATTR)
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
