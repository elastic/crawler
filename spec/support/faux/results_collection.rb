# frozen_string_literal: true

require 'concurrent'

# A simple wrapper class for a collection of crawl results gathered by the mock crawler sink
class ResultsCollection
  attr_accessor :crawl_config, :crawl, :collection

  delegate :outcome, :outcome_message, to: :crawl

  def initialize
    @collection = Concurrent::Array.new
  end

  # Do not allow the collection to be duplicated when passed through config validation, etc
  # This is needed so that we could pass a collection as a config parameter to a Crawler instance
  # in tests and get it propagated to the sink itself and back.
  def dup
    self
  end

  def method_missing(meth, *args, &block)
    @collection.send(meth, *args, &block)
  end

  def respond_to_missing?(method_name, include_private = false)
    @collection.respond_to?(method_name, include_private) || super
  end
end
