# frozen_string_literal: true

require('elasticsearch')
require('json')

require_dependency File.join(__dir__, 'base')

module Crawler
  class OutputSink::Elasticsearch < OutputSink::Base
    MEGABYTES_100 = 100 * 1024 * 1024 # 100 megabytes in bytes

    def initialize(*)
      super

      es_config = config.elasticsearch

      if es_config['api_key']
        # TODO: log
        @client = Elasticsearch::Client.new(
          host: es_config['host'],
          api_key: es_config['api_key']
        )
      else
        # TODO: log
        basic_auth_url = es_config['host'].sub(/^https?:\/\//) do|match|
          "#{match}#{es_config['username']}:#{es_config['password']}@"
        end
        @client = Elasticsearch::Client.new(url: basic_auth_url)
      end
      @index_name = config.output_index
      @doc_backlog = []
      @backlog_size = 0
    end

    def write(crawl_result)
      doc = to_doc(crawl_result)
      payload = update_payload(doc)

      response = send_bulk(payload)

      # ES HTTP requests have a 100MB limit, so if the next doc would put the bulk request body over that limit
      # We send off the current backlog as a bulk index request and begin filling the backlog again
      # if @backlog_size + array_size([doc]) > 1#MEGABYTES_100
      #   response = send_bulk
      #
      #   @doc_backlog.clear
      # end

      # update_backlog(doc)

      success
    end

    def close
      # unless @doc_backlog.empty?
      #   response = send_bulk
      # end
    end

    def send_bulk(payload)
      system_logger.info(@index_name)
      system_logger.info(payload)

      response = @client.bulk(
        index: @index_name,
        body: payload
      )

      system_logger.info(response)

      response
    end

    def update_payload(doc)
      # @doc_backlog.append({ update: { _index: @index_name, _id: doc['_id'] } }.deep_stringify_keys)
      # @doc_backlog.append({ doc: doc, doc_as_upsert: true}.deep_stringify_keys)
      # @backlog_size = array_size(@doc_backlog)
      payload = []
      payload.append({ update: { _index: @index_name, _id: doc['id'] } })
      payload.append({ doc: doc, doc_as_upsert: true })
      payload
      # @backlog_size = array_size(@doc_backlog)
    end

    def array_size(array)
      ActiveSupport::JSON.encode(array).size
    end
  end
end
