#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  class Utils
    def self.url_pattern(domain, type, pattern)
      "\\A#{Regexp.escape(domain)}#{path_pattern(type, pattern)}"
    end

    def self.path_pattern(type, pattern)
      case type
      when 'begins'
        pattern_with_wildcard(pattern)
      when 'ends'
        ".*#{pattern_with_wildcard(pattern)}\\z"
      when 'contains'
        ".*#{pattern_with_wildcard(pattern)}"
      when 'regex'
        pattern
      end
    end

    def self.pattern_with_wildcard(pattern)
      Regexp.escape(pattern).gsub('\*', '.*')
    end
  end
end
