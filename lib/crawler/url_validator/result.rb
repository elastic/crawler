# frozen_string_literal: true

class Crawler::UrlValidator::Result
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
