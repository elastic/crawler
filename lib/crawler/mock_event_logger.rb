# frozen_string_literal: true

require 'logger'

module Crawler
  class MockEventLogger
    # Array of accumulated events (hash objects).
    attr_reader :mock_events

    def initialize
      @mock_events = []
    end

    def <<(event)
      # Since we receive an already serialized event, but want to run tests against raw events
      original_event = JSON.parse(event)
      mock_events << original_event
    end
  end
end
