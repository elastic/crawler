# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')
require_dependency File.join(__dir__, '..', '..', 'utility', 'es_client')
require_dependency File.join(__dir__, '..', '..', 'utility', 'bulk_queue')

module Crawler
  module OutputSink
    class Elasticsearch < OutputSink::Base
      def initialize(config) # rubocop:disable Metrics/MethodLength
        super

        raise ArgumentError, 'Missing output index' unless config.output_index

        raise ArgumentError, 'Missing elasticsearch configuration' unless config.elasticsearch

        @index_name = config.output_index

        es_config = config.elasticsearch
        @client = Utility::EsClient.new(es_config, system_logger)
        @operation_queue = Utility::BulkQueue.new(
          es_config.dig(:bulk_api, :max_items),
          es_config.dig(:bulk_api, :max_size_bytes),
          system_logger
        )

        @queued = {
          indexed_document_count: 0,
          indexed_document_volume: 0
        }
        @completed = {
          indexed_document_count: 0,
          indexed_document_volume: 0
        }
      end

      def write(crawl_result) # rubocop:disable Metrics/MethodLength
        doc = to_doc(crawl_result)
        payload = { doc: doc }
        index_op = { 'index' => { '_index' => @index_name, '_id' => doc['id'] } }

        flush unless @operation_queue.will_fit?(index_op, payload)

        @operation_queue.add(
          index_op,
          payload
        )
        system_logger.debug("Added doc #{doc['id']} to bulk queue. Current stats: #{@operation_queue.current_stats}")

        @queued[:indexed_document_count] += 1
        @queued[:indexed_document_volume] += @operation_queue.bytesize(payload)

        success
      end

      def close
        flush
        system_logger.info(ingestion_stats)
      end

      def flush # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        data = @operation_queue.pop_all
        if data.empty?
          system_logger.debug('Queue was empty when attempting to flush.')
          return
        end

        system_logger.debug("Sending bulk request with #{data.size} items and flushing queue...")

        begin
          @client.bulk(body: data) # TODO: add pipelines, parse response
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
    end
  end
end
