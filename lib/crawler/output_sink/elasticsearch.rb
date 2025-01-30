#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, 'base')
require_dependency File.join(__dir__, '..', '..', 'es', 'client')
require_dependency File.join(__dir__, '..', '..', 'es', 'bulk_queue')
require_dependency File.join(__dir__, '..', '..', 'errors')

module Crawler
  module OutputSink
    class Elasticsearch < OutputSink::Base
      DEFAULT_PIPELINE = 'ent-search-generic-ingestion'
      DEFAULT_PIPELINE_PARAMS = {
        _reduce_whitespace: true,
        _run_ml_inference: true,
        _extract_binary_content: true
      }.freeze
      SEARCH_PAGINATION_SIZE = 1_000

      def initialize(config)
        super

        raise ArgumentError, 'Missing output index' unless config.output_index

        raise ArgumentError, 'Missing elasticsearch configuration' unless config.elasticsearch

        @config = config
        # initialize client now to fail fast if config is bad
        client

        # ping ES by attempting to reach the index specified in config
        ping_output_index

        @queue_lock = Mutex.new
        init_ingestion_stats
        system_logger.info(
          "Elasticsearch sink initialized for index [#{index_name}] with pipeline [#{pipeline}]"
        )
      end

      def ping_output_index
        raise Errors::IndexDoesNotExistError, system_logger.info("Failed to find index #{config.output_index}") unless
          client.indices.exists(index: config.output_index)
      end

      def write(crawl_result)
        # make additions to the operation queue thread-safe
        raise Errors::SinkLockedError unless @queue_lock.try_lock

        begin
          doc = parametrized_doc(crawl_result)
          index_op = { index: { _index: index_name, _id: doc[:id] } }

          flush unless operation_queue.will_fit?(index_op, doc)

          operation_queue.add(
            index_op,
            doc
          )
          system_logger.debug("Added doc #{doc[:id]} to bulk queue. Current stats: #{operation_queue.current_stats}")

          increment_ingestion_stats(doc)
          success("Successfully added #{doc[:id]} to the bulk queue")
        ensure
          @queue_lock.unlock
        end
      end

      def fetch_purge_docs(crawl_start_time)
        query = {
          _source: ['url'],
          query: {
            range: {
              last_crawled_at: {
                lt: crawl_start_time.rfc3339
              }
            }
          },
          size: SEARCH_PAGINATION_SIZE,
          sort: [{ last_crawled_at: 'asc' }]
        }.deep_stringify_keys
        system_logger.debug(
          "Fetching docs for pages that were not encountered during the sync. Full query: #{query.inspect}"
        )

        client.indices.refresh(index: [index_name])
        hits = client.paginated_search(index_name, query)
        hits.map { |h| h['_source']['url'] }
      end

      def purge(crawl_start_time)
        query = {
          _source: ['url'],
          query: {
            range: {
              last_crawled_at: {
                lt: crawl_start_time.rfc3339
              }
            }
          }
        }.deep_stringify_keys

        system_logger.info('Deleting docs for pages that were not accessible during the purge crawl.')
        system_logger.debug("Full delete query: #{query}")

        client.indices.refresh(index: [index_name])
        response = client.delete_by_query(index: [index_name], body: query)
        system_logger.debug("Delete by query response: #{response}")

        @deleted = response['deleted']
      end

      def close
        msg = <<~LOG.squish
          All indexing operations completed.
          Successfully upserted #{@completed[:docs_count]} docs with a volume of #{@completed[:docs_volume]} bytes.
          Failed to index #{@failed[:docs_count]} docs with a volume of #{@failed[:docs_volume]} bytes.
          Deleted #{@deleted} outdated docs from the index.
        LOG
        system_logger.info(msg)
      end

      def flush # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        body = operation_queue.pop_all
        if body.empty?
          system_logger.debug('Queue was empty when attempting to flush.')
          return
        end

        # a single doc needs two items in a bulk request, so halving the count makes logs clearer
        indexing_docs_count = body.size / 2
        system_logger.info("Sending bulk request with #{indexing_docs_count} items and resetting queue...")

        begin
          client.bulk(body:, pipeline:) # TODO: parse response
          system_logger.info("Successfully indexed #{indexing_docs_count} docs.")
          reset_ingestion_stats(true)
        rescue ES::Client::IndexingFailedError => e
          system_logger.warn("Bulk index failed: #{e}")
          reset_ingestion_stats(false)
        rescue StandardError => e
          system_logger.warn("Bulk index failed for unexpected reason: #{e}")
          reset_ingestion_stats(false)
        end
      end

      def ingestion_stats
        { completed: @completed.dup, failed: @failed.dup }
      end

      def operation_queue
        @operation_queue ||= ES::BulkQueue.new(
          es_config.dig(:bulk_api, :max_items),
          es_config.dig(:bulk_api, :max_size_bytes),
          system_logger
        )
      end

      def es_config
        @es_config ||= @config.elasticsearch
      end

      def client
        @client ||= ES::Client.new(es_config, system_logger, Crawler.version, crawl_id)
      end

      def index_name
        @index_name ||= @config.output_index
      end

      def pipeline
        @pipeline ||= pipeline_enabled? ? (es_config[:pipeline] || DEFAULT_PIPELINE) : nil
      end

      def pipeline_enabled?
        @pipeline_enabled ||=
          if es_config[:pipeline_enabled].nil?
            true
          else
            es_config[:pipeline_enabled]
          end
      end

      def pipeline_params
        @pipeline_params ||= DEFAULT_PIPELINE_PARAMS.merge(es_config[:pipeline_params] || {})
      end

      private

      def parametrized_doc(crawl_result)
        doc = to_doc(crawl_result)
        doc.merge!(pipeline_params) if pipeline_enabled?
        doc
      end

      def init_ingestion_stats
        @queued = {
          docs_count: 0,
          docs_volume: 0
        }
        @completed = {
          docs_count: 0,
          docs_volume: 0
        }
        @failed = {
          docs_count: 0,
          docs_volume: 0
        }
        @deleted = 0
      end

      def increment_ingestion_stats(doc)
        @queued[:docs_count] += 1
        @queued[:docs_volume] += operation_queue.bytesize(doc)
      end

      def reset_ingestion_stats(success)
        if success
          @completed[:docs_count] += @queued[:docs_count]
          @completed[:docs_volume] += @queued[:docs_volume]
        else
          @failed[:docs_count] += @queued[:docs_count]
          @failed[:docs_volume] += @queued[:docs_volume]
        end

        @queued[:docs_count] = 0
        @queued[:docs_volume] = 0
      end
    end
  end
end
