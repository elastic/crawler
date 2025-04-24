# frozen_string_literal: true

require 'webmock/rspec'

RSpec.describe Crawler::ZendeskCrawler do
  let(:zendesk_url) { 'https://support.zendesk.com/api/v2/help_center/en-us/articles.json' }
  let(:es_client) { instance_double(Elasticsearch::Client, indices: indices_double) }
  let(:indices_double) { instance_double(Elasticsearch::API::Indices::IndicesClient) }

  subject(:crawler) do
    described_class.new(zendesk_url, es_client)
  end

  describe '#initialize' do
    it 'sets the instance variables correctly' do
      expect(crawler.instance_variable_get(:@zendesk_url)).to eq(zendesk_url)
      expect(crawler.instance_variable_get(:@es_client)).to eq(es_client)
      expect(crawler.instance_variable_get(:@index_name)).to eq('articles')
      expect(crawler.instance_variable_get(:@per_page)).to eq(30)
      expect(crawler.instance_variable_get(:@faraday_client)).to be_a(Faraday::Connection)
    end
  end

  describe '#index_mapping' do
    it 'returns the correct mapping structure' do
      expected_mapping = {
        properties: {
          html_url: { type: 'text' },
          title: { type: 'text' },
          body: { type: 'text' },
          labels: { type: 'keyword' }
        }
      }
      expect(crawler.index_mapping).to eq(expected_mapping)
    end
  end

  describe '#create_index_with_mapping' do
    context 'when index does not exist' do
      before do
        allow(indices_double).to receive(:exists?).and_return(false)
      end

      it 'creates the index with the correct mapping' do
        expect(indices_double).to receive(:create)
          .with(index: 'articles', body: { mappings: crawler.index_mapping })
        crawler.create_index_with_mapping
      end
    end

    context 'when index already exists' do
      before do
        allow(indices_double).to receive(:exists?).and_return(true)
      end

      it 'does not attempt to create the index' do
        expect(indices_double).not_to receive(:create)
        crawler.create_index_with_mapping
      end
    end
  end

  describe '#fetch_page_data' do
    let(:url) { 'https://support.zendesk.com/api/v2/help_center/en-us/articles.json?page=1' }
    let(:response_body) { { 'articles' => [], 'next_page' => nil }.to_json }

    context 'when request is successful' do
      before do
        stub_request(:get, url).to_return(
          status: 200,
          body: response_body,
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'fetches and parses the page data' do
        result = crawler.fetch_page_data(url)
        expect(result).to eq({ 'articles' => [], 'next_page' => nil })
      end
    end

    context 'when request fails' do
      let(:error_status) { 500 }
      let(:error_body) { 'Internal Server Error' }

      before do
        stub_request(:get, url).to_return(
          status: error_status,
          body: error_body,
          headers: {}
        )
      end

      it 'raises an error' do
        expect { crawler.fetch_page_data(url) }.to raise_error(/HTTP Error: #{error_status}/)
      end
    end
  end

  describe '#clean_html' do
    it 'removes HTML tags and decodes entities' do
      html = '<p>Hello &amp; Welcome</p><a href="#"> Click here</a>'
      expect(crawler.clean_html(html)).to eq('Hello & Welcome Click here')
    end

    it 'handles nil input' do
      expect(crawler.clean_html(nil)).to eq('')
    end
  end

  describe '#prepare_article_document' do
    let(:article) do
      {
        'id' => 123,
        'html_url' => 'https://example.com/article',
        'title' => 'Test Article',
        'body' => '<p>Content</p>',
        'label_names' => %w[how-to guide]
      }
    end

    it 'prepares the document correctly' do
      result = crawler.prepare_article_document(article)
      expect(result).to eq(
        {
          _id: 123,
          html_url: 'https://example.com/article',
          title: 'Test Article',
          body: 'Content',
          labels: %w[how-to guide]
        }
      )
    end
  end

  describe '#prepare_bulk_operations' do
    let(:documents) do
      [
        { _id: 1, title: 'Doc 1', body: 'Content 1' },
        { _id: 2, title: 'Doc 2', body: 'Content 2' }
      ]
    end

    it 'prepares correct bulk operations' do
      result = crawler.prepare_bulk_operations(documents)
      expect(result).to eq(
        [
          { index: { _index: 'articles', _id: 1, data: { title: 'Doc 1', body: 'Content 1' } } },
          { index: { _index: 'articles', _id: 2, data: { title: 'Doc 2', body: 'Content 2' } } }
        ]
      )
    end
  end

  describe '#index_documents' do
    let(:documents) { [{ _id: 1, title: 'Test' }] }
    let(:bulk_response) { { 'errors' => false } }

    before do
      allow(es_client).to receive(:bulk).and_return(bulk_response)
    end

    it 'indexes documents successfully' do
      expect(es_client).to receive(:bulk).with(body: anything)
      expect(crawler.index_documents(documents)).to be true
    end

    context 'when bulk indexing has errors' do
      let(:bulk_response) { { 'errors' => true, 'items' => [] } }

      it 'returns false' do
        expect(es_client).to receive(:bulk).with(body: anything)
        expect(crawler.index_documents(documents)).to be false
      end
    end
  end

  describe '#process_page' do
    let(:url) { "#{zendesk_url}?page=1" }
    let(:next_url) { "#{zendesk_url}?page=2" }
    let(:page_data) do
      {
        'articles' => [{
          'id' => 1,
          'html_url' => 'https://example.com/1',
          'title' => 'Article 1',
          'body' => '<p>Content</p>',
          'label_names' => ['test']
        }],
        'next_page' => next_url,
        'page' => 1
      }
    end

    before do
      stub_request(:get, url).to_return(
        status: 200,
        body: page_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      allow(crawler).to receive(:index_documents).and_return(true)
      allow(crawler).to receive(:fetch_page_data).and_call_original
    end

    it 'processes a page successfully and returns next page url' do
      result = crawler.process_page(url, 1)
      expect(result[:success]).to be true
      expect(result[:next_page_url]).to eq(next_url)
      expect(crawler).to have_received(:fetch_page_data).with(url)
      expect(crawler).to have_received(:index_documents)
    end

    context 'when fetching page data fails' do
      before do
        stub_request(:get, url).to_return(status: 500)
        allow(crawler).to receive(:fetch_page_data).and_call_original
      end

      it 'returns failure status and no next page url' do
        result = crawler.process_page(url, 1)
        expect(result[:success]).to be false
        expect(result[:next_page_url]).to be_nil
        expect(crawler).not_to have_received(:index_documents)
        expect(crawler).to have_received(:fetch_page_data)
      end
    end

    context 'when indexing documents fails' do
      let(:page_data_with_next) do
        {
          'articles' => [{
            'id' => 1,
            'html_url' => 'https://example.com/1',
            'title' => 'Article 1',
            'body' => '<p>Content</p>',
            'label_names' => ['test']
          }],
          'next_page' => next_url,
          'page' => 1
        }
      end

      before do
        stub_request(:get, url).to_return(
          status: 200,
          body: page_data_with_next.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
        allow(crawler).to receive(:index_documents).and_return(false)
        allow(crawler).to receive(:fetch_page_data).and_call_original
      end

      it 'returns failure status but includes the next page url from the fetched data' do
        result = crawler.process_page(url, 1)
        expect(result[:success]).to be false
        expect(result[:next_page_url]).to eq(next_url)
        expect(crawler).to have_received(:index_documents)
        expect(crawler).to have_received(:fetch_page_data)
      end
    end
  end

  describe '#run' do
    let(:initial_process_url) { zendesk_url }
    let(:first_fetch_url) { "#{zendesk_url}?page=1" }
    let(:page2_url) { "#{zendesk_url}?page=2" }
    let(:page3_url) { "#{zendesk_url}?page=3" }
    let(:sample_article1) do
      { 'id' => 1, 'title' => 'Article 1', 'body' => '<p>Body 1</p>', 'html_url' => 'url1', 'label_names' => ['tag1'] }
    end
    let(:sample_article2) do
      { 'id' => 2, 'title' => 'Article 2', 'body' => '<p>Body 2</p>', 'html_url' => 'url2', 'label_names' => ['tag2'] }
    end

    let(:page1_data) do
      {
        'articles' => [sample_article1],
        'next_page' => page2_url,
        'page' => 1
      }
    end

    let(:page2_data) do
      {
        'articles' => [sample_article2],
        'next_page' => page3_url,
        'page' => 2
      }
    end

    let(:page3_data) do
      {
        'articles' => [],
        'next_page' => nil,
        'page' => 3
      }
    end

    before do
      allow(crawler).to receive(:create_index_with_mapping)
      allow(crawler).to receive(:index_documents).and_return(true)
      allow(crawler).to receive(:fetch_page_data).and_call_original
      allow(crawler).to receive(:process_page).and_call_original

      stub_request(:get, first_fetch_url).to_return(
        status: 200,
        body: page1_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      stub_request(:get, page2_url).to_return(
        status: 200,
        body: page2_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      stub_request(:get, page3_url).to_return(
        status: 200,
        body: page3_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end
  end
end
