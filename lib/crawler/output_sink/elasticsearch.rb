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
    end

    def write(crawl_result)
      # TODO: run this in an async buffer
      # max documents count
      # max size
      # max time waited
      # then flush if conditions to meet
      doc = to_doc(crawl_result)
      payload = update_payload(doc)
      response = send_bulk(payload)

      return success unless response.body['errors']

      errors = response.body['items'].map do |item|
        error = item['update']['error']
        next unless error

        "#{error['type']}: #{error['reason']}"
      end

      failure(errors.compact.join(', '))
    end

    def send_bulk(payload)
      @client.bulk(
        index: @index_name,
        body: payload
      )
    end

    def update_payload(doc)
      # TODO: run this in an async buffer
      payload = []
      payload.append({ update: { _index: @index_name, _id: doc['id'] } })
      payload.append({ doc: doc, doc_as_upsert: true })
      payload
    end

    def array_size(array)
      ActiveSupport::JSON.encode(array).size
    end
  end
end
