# frozen_string_literal: true

require_dependency File.join(__dir__, '..', 'output_sink')

module Crawler
  class OutputSink::Base
    attr_reader :config, :rule_engine

    delegate :events, :to => :config

    def initialize(config)
      @config = config
      @rule_engine = create_rule_engine
    end

    def create_rule_engine
      Crawler::RuleEngine::Base.new(config)
    end

    def write(_crawl_result)
      raise NotImplementedError
    end

    def close
      # To be implemented by the sink if needed.
      # Does nothing by default.
    end

    #-----------------------------------------------------------------------------------------------
    # Returns a hash with the outcome of crawl result ingestion (to be used for logging above)
    def outcome(outcome, message)
      { :outcome => outcome, :message => message }
    end

    def success(message = 'Successfully ingested crawl result')
      outcome(:success, message)
    end

    def failure(message)
      outcome(:failure, message)
    end
  end
end
