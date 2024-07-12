#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, '..', 'output_sink')

module Crawler
  module OutputSink
    class Base
      attr_reader :config, :rule_engine

      delegate :crawl_id, :document_mapper, :events, :system_logger, to: :config

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

      def to_doc(crawl_result)
        doc = { id: crawl_result.url_hash }
        doc.merge!(document_mapper.document_fields(crawl_result))
        doc.merge!(document_mapper.url_components(crawl_result.url))
        doc.merge!(document_mapper.extract_by_rules(crawl_result, config.extraction_rules))
        doc.deep_stringify_keys!
      end

      def close
        # To be implemented by the sink if needed.
        # Does nothing by default.
      end

      #-----------------------------------------------------------------------------------------------
      # Returns a hash with the outcome of crawl result ingestion (to be used for logging above)
      def outcome(outcome, message)
        { outcome:, message: }
      end

      def success(message = 'Successfully ingested crawl result')
        outcome(:success, message)
      end

      def failure(message)
        outcome(:failure, message)
      end
    end
  end
end
