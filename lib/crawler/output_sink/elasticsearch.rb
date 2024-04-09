# frozen_string_literal: true

require('elasticsearch/api')

require_dependency File.join(__dir__, 'base')
require_dependency File.join(__dir__, '..', '..', 'utility', 'es_client')
require_dependency File.join(__dir__, '..', '..', 'utility', 'bulk_queue')

module Crawler
  class OutputSink::Elasticsearch < OutputSink::Base
    def initialize(config)
      super

      unless config.output_index
        raise ArgumentError, 'Missing output index'
      end

      unless config.elasticsearch
        raise ArgumentError, 'Missing elasticsearch configuration'
      end

      @index_name = config.output_index
      @client = Utility::EsClient.new(config.elasticsearch)
      @operation_queue = Utility::BulkQueue.new

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
      doc = to_doc(crawl_result)
      serialized_doc = serialize({ 'doc': doc })
      serialized_doc_size = serialized_doc.bytesize

      index_op = serialize({ 'index' => { '_index' => @index_name, '_id' => doc['id'] } })

      flush unless @operation_queue.will_fit?(index_op, serialized_doc)

      @operation_queue.add(
        index_op,
        serialized_doc
      )
      system_logger.debug("Added doc #{doc['id']} to bulk queue. Current stats: #{@operation_queue.current_stats}")

      @queued[:indexed_document_count] += 1
      @queued[:indexed_document_volume] += serialized_doc_size

      success
    end

    def close
      flush
      system_logger.info(ingestion_stats)
    end

    def flush
      data = @operation_queue.pop_all
      if data.empty?
        system_logger.debug('Queue was empty when attempting to flush.')
        return
      end

      system_logger.debug("Sending bulk request with #{data.size} items and flushing queue...")

      begin
        response = @client.bulk(:body => data) # TODO: add pipelines
      rescue Utility::EsClient::IndexingFailedError => e
        system_logger.warn("Bulk index failed: #{e}")
      rescue StandardError => e
        system_logger.warn("Bulk index failed for unexpected reason: #{e}")
        system_logger.debug("Bulk API request body: #{data}")
        system_logger.debug("Response: #{response}")
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

    private

    def serialize(document)
      Elasticsearch::API.serializer.dump(document)
    end
  end
end
