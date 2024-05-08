#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  # Current version of the crawler
  def self.version
    @version ||= File.read(File.join(__dir__, '../product_version')).strip
  end

  # A unique identifier of the crawler process
  def self.service_id
    @service_id ||= BSON::ObjectId.new.to_s
  end
end

# Load other parts of the crawler
# Ignore Crawler CLI
Dir[File.join(__dir__, 'crawler/**/*.rb')].reject { |file| file =~ %r{\/crawler\/cli\/} }.each { |f| require_dependency(f) }
