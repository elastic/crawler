#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  class UrlValidator::Result # rubocop:disable Style/ClassAndModuleChildren
    attr_reader :name, :result, :comment, :details

    def initialize(name:, result:, comment:, details: {})
      @name = name
      @result = result
      @comment = comment
      @details = details
    end

    def failure?
      result == :failure
    end

    def to_h
      { name:, result:, comment: }.tap do |res|
        res[:details] = details if details.any?
      end
    end
  end
end
