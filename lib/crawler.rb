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
Dir[File.join(__dir__, 'crawler/**/*.rb')].each { |f| require_dependency(f) }
