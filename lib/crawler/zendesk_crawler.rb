# frozen_string_literal: true

require 'faraday'
require 'json'
require 'elasticsearch'
require 'cgi'

module Crawler
  ZENDESK_API_URL = 'https://support.zendesk.com/api/v2/help_center/en-us/articles.json?page=1&per_page=100'
  ELASTICSEARCH_URL = 'http://localhost:9200'

  class ZendeskCrawler
    # Initializes the indexer with the Zendesk API URL and Elasticsearch client.
    # @param zendesk_url [String] The base URL for the Zendesk articles API.
    # @param es_client [Elasticsearch::Client] The Elasticsearch client instance.
    def initialize(zendesk_url, es_client)
      @zendesk_url = zendesk_url
      @es_client = es_client
      @index_name = 'articles'

      # Configure Faraday connection without the raise_error middleware
      @faraday_client = Faraday.new(url: @zendesk_url) do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
    end

    # Defines the Elasticsearch index mapping.
    # @return [Hash] The mapping structure.
    def index_mapping
      {
        properties: {
          html_url: { type: 'text' },
          title: { type: 'text' },
          body: { type: 'text' },
          labels: { type: 'keyword' }
        }
      }
    end

    # Creates the Elasticsearch index with the specified mapping if it doesn't exist.
    # Raises an error if index creation fails.
    def create_index_with_mapping
      if @es_client.indices.exists?(index: @index_name)
        puts "Index '#{@index_name}' already exists."
      else
        puts "Creating Elasticsearch index '#{@index_name}' with mapping..."
        begin
          @es_client.indices.create(index: @index_name, body: { mappings: index_mapping })
          puts "Index '#{@index_name}' created successfully."
        rescue Elasticsearch::API => e
          puts "Elasticsearch error: #{e.message}."
          raise
        rescue StandardError => e
          puts "An unexpected error occurred during index creation: #{e.message}"
          raise
        end
      end
    end

    # Fetches data from a given URL and parses the JSON response.
    # Checks the HTTP status and raises an error for unsuccessful responses.
    # @param url [String] The URL to fetch data from.
    # @return [Hash] The parsed JSON response data.
    # @raise [RuntimeError, JSON::ParserError, StandardError] Raises exceptions on failure.
    def fetch_page_data(url)
      response = @faraday_client.get(url)

      raise "HTTP Error: #{response.status} - #{response.reason_phrase} for URL: #{url}" unless response.success?

      JSON.parse(response.body)
    end

    # Cleans HTML tags from a string.
    # @param html_string [String, nil] The string containing HTML.
    # @return [String] The cleaned string with HTML tags removed.
    def clean_html(html_string)
      return '' if html_string.nil?

      # Decode HTML entities (like &amp;)
      cleaned_string = CGI.unescapeHTML(html_string)

      # Remove all HTML tags, including those with attributes and content within <a>
      # This regex removes anything that looks like a tag: <...>
      cleaned_string = cleaned_string.gsub(/<[^>]*>/, '')

      # Replace multiple newlines/whitespace with a single space or newline
      cleaned_string.gsub(/[\r\n]+/, "\n").gsub(/[ \t]+/, ' ').strip
    end

    # Prepares a single article hash for indexing in Elasticsearch.
    # Cleans the body and selects relevant fields.
    # @param article [Hash] The raw article hash from the Zendesk API.
    # @return [Hash] The prepared document hash for Elasticsearch, including _id.
    def prepare_article_document(article)
      {
        _id: article['id'],
        html_url: article['html_url'],
        title: article['title'],
        body: clean_html(article['body']),
        labels: article['label_names']
      }.compact
    end

    # Prepares bulk operations from a list of prepared documents.
    # @param documents [Array<Hash>] An array of prepared document hashes (including _id).
    # @return [Array<Hash>] An array of bulk indexing operations.
    def prepare_bulk_operations(documents)
      documents.map do |doc|
        { index: { _index: @index_name, _id: doc[:_id], data: doc.except(:_id) } }
      end
    end

    # Reports errors found in the Elasticsearch bulk response.
    # @param bulk_response [Hash] The response hash from the Elasticsearch bulk API.
    def report_bulk_errors(bulk_response)
      puts 'Bulk indexing errors occurred:'
      bulk_response['items'].each do |item|
        if item['index'] && item['index']['error']
          puts "  ID: #{item['index']['_id']}, Error: #{item['index']['error']['reason']}"
        end
      end
    end

    # Indexes a batch of prepared documents into Elasticsearch using the bulk API.
    # @param documents [Array<Hash>] An array of prepared document hashes (including _id).
    # @return [Boolean] True if indexing was successful for the batch, false otherwise.
    def index_documents(documents)
      return true if documents.empty?

      operations = prepare_bulk_operations(documents)

      begin
        bulk_response = @es_client.bulk(body: operations)

        if bulk_response['errors']
          report_bulk_errors(bulk_response)
          false
        else
          puts "Successfully indexed #{documents.length} articles."
          true
        end
      rescue Elasticsearch::API => e
        puts "Elasticsearch error: #{e.message}"
        true
      rescue StandardError => e
        puts "An unexpected error occurred during bulk indexing: #{e.message}"
        false
      end
    end

    # Processes a single page: fetches data, prepares documents, and indexes them.
    # @param url [String] The URL of the page to process.
    # @param page_number [Integer] The current page number for logging.
    # @return [Hash, nil] A hash containing `next_page_url` and `success` status, or nil if a critical error occurred.
    def process_page(url, page_number)
      puts "Processing page #{page_number}..."
      begin
        page_data = fetch_page_data(url)

        articles = page_data['articles']
        next_page_url = page_data['next_page']
        current_page_from_api = page_data['page']

        puts "Fetched #{articles.length} articles from page #{current_page_from_api}."

        if articles.empty?
          puts "No articles found on page #{current_page_from_api}. Stopping."
          return { next_page_url: nil, success: true } # Indicate success but no more pages
        end

        docs_to_index = articles.map { |article| prepare_article_document(article) }
        indexing_successful = index_documents(docs_to_index)

        { next_page_url:, success: indexing_successful }
      rescue RuntimeError => e
        puts "Error fetching or processing page #{page_number}: #{e.message}"
        { next_page_url: nil, success: false }
      rescue JSON::ParserError => e
        puts "JSON parsing error for #{url}: #{e.message}"
        { next_page_url: nil, success: false }
      rescue StandardError => e
        puts "An unexpected error occurred while processing page #{page_number}: #{e.message}"
        { next_page_url: nil, success: false }
      end
    end

    # Main method to run the fetching and indexing process page by page.
    # Handles pagination and overall process flow.
    def run
      create_index_with_mapping

      current_url = @zendesk_url
      page_number = 1

      puts 'Starting article indexing process...'

      while current_url
        page_result = process_page(current_url, page_number)

        # Break the loop if processing the page was not successful
        break unless page_result[:success]

        current_url = page_result[:next_page_url]
        page_number += 1

        sleep(0.5) if current_url
      end

      puts 'Finished indexing process.'
    end
  end

  # --- Execution ---
  # Add a helper method to Hash for `except`
  unless Hash.instance_methods.include?(:except)
    class Hash
      def except(*keys)
        dup.except!(*keys)
      end

      def except!(*keys)
        keys.each { |key| delete(key) }
        self
      end
    end
  end

  begin
    # Initialize Elasticsearch client
    # log: true can be helpful for debugging Elasticsearch interactions
    es_client = Elasticsearch::Client.new(url: ELASTICSEARCH_URL, log: false)

    # Initialize and run the indexer
    indexer = ZendeskCrawler.new(ZENDESK_API_URL, es_client)
    indexer.run
  rescue Faraday::ConnectionFailed => e
    puts "Failed to connect to Zendesk API: #{e.message}. Please check the URL and your network connection."
  rescue Elasticsearch::API => e
    puts "Elasticsearch error: #{e.message} for #{ELASTICSEARCH_URL}."
  rescue StandardError => e
    puts "An unhandled error occurred during the main execution flow: #{e.message}"
  end
end
