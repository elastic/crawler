# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')
require_dependency File.join(__dir__, '..', '..', 'utility', 'es_client')
require_dependency File.join(__dir__, '..', '..', 'utility', 'bulk_queue')

module Crawler
  class OutputSink::Elasticsearch < OutputSink::Base
    DEFAULT_PIPELINE = 'ent-search-generic-ingestion'.freeze
    DEFAULT_PIPELINE_PARAMS = {
      _reduce_whitespace: true,
      _run_ml_inference: true,
      _extract_binary_content: true
    }.freeze

    def initialize(config)
      super

      unless config.output_index
        raise ArgumentError, 'Missing output index'
      end

      unless config.elasticsearch
        raise ArgumentError, 'Missing elasticsearch configuration'
      end

      @config = config
      system_logger.info(
        "Elasticsearch sink initialized for index [#{index_name}] with pipeline [#{pipeline}]"
      )

      @queued = {
        :indexed_document_count => 0,
        :indexed_document_volume => 0
      }
      @completed = {
        :indexed_document_count => 0,
        :indexed_document_volume => 0
      }
    end

    def write(crawl_result)
      doc = to_doc(crawl_result).merge!(pipeline_params)
      index_op = { 'index' => { '_index' => index_name, '_id' => doc['id'] } }

      flush unless operation_queue.will_fit?(index_op, doc)

      operation_queue.add(
        index_op,
        doc
      )
      system_logger.debug("Added doc #{doc['id']} to bulk queue. Current stats: #{operation_queue.current_stats}")

      @queued[:indexed_document_count] += 1
      @queued[:indexed_document_volume] += operation_queue.bytesize(doc)

      success
    end

    def close
      flush
      system_logger.info(ingestion_stats)
    end

    def flush
      data = operation_queue.pop_all
      if data.empty?
        system_logger.debug('Queue was empty when attempting to flush.')
        return
      end

      system_logger.debug("Sending bulk request with #{data.size} items and flushing queue...")

      begin
        response = client.bulk(body: data, pipeline: pipeline) # TODO: parse response
      rescue Utility::EsClient::IndexingFailedError => e
        system_logger.warn("Bulk index failed: #{e}")
      rescue StandardError => e
        system_logger.warn("Bulk index failed for unexpected reason: #{e}")
        raise e
      end

      system_logger.debug("Bulk request containing #{data.size} items sent!")

      # TODO: this count isn't accurate, need to look into it
      @completed[:indexed_document_count] += @queued[:indexed_document_count]
      @completed[:indexed_document_volume] += @queued[:indexed_document_volume]

      @queued[:indexed_document_count] = 0
      @queued[:indexed_document_volume] = 0
    end

    def ingestion_stats
      @completed.dup
    end

    def operation_queue
      @operation_queue ||= Utility::BulkQueue.new(
        es_config.dig(:bulk_api, :max_items),
        es_config.dig(:bulk_api, :max_size_bytes),
        system_logger
      )
    end

    def es_config
      @es_config ||= @config.elasticsearch
    end

    def client
      @client ||= Utility::EsClient.new(es_config, system_logger)
    end

    def index_name
      @index_name ||= @config.output_index
    end

    def pipeline
      @pipeline ||= es_config[:pipeline] || DEFAULT_PIPELINE
    end

    def pipeline_params
      @pipeline_params ||= DEFAULT_PIPELINE_PARAMS.merge(es_config[:pipeline_params] || {}).deep_stringify_keys
    end
  end
end
