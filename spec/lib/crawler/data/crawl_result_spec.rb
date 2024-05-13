#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::CrawlResult) do
  let(:url) { Crawler::Data::URL.parse('https://example.com/') }
  let(:html_crawl_result) do
    Crawler::Data::CrawlResult::HTML.new(
      url:,
      content: html
    )
  end

  let(:html) do
    <<~HTML
      <html>
        <head>
          <title>Under construction...</title>
          <link rel="canonical" href="https://example.com/canonical" />
          <meta name="keywords" content="keywords, stuffing, SEO" />
          <meta name="description" content="The best site in the universe!" />
        </head>
        <body>
          Hello, World!
        <body>
      </html>
    HTML
  end

  let(:error) { 'Something is wrong!' }
  let(:error_crawl_result) do
    Crawler::Data::CrawlResult::Error.new(
      url:,
      error:
    )
  end

  let(:unsupported_content_type_crawl_result) do
    Crawler::Data::CrawlResult::UnsupportedContentType.new(
      url:,
      status_code: 200,
      content_type: 'audio/midi'
    )
  end

  #-------------------------------------------------------------------------------------------------
  describe '.to_h' do
    it 'should return a hash with a set of key fields' do
      expect(html_crawl_result.to_h).to be_kind_of(Hash)
      expect(html_crawl_result.to_h).to include(:id, :url_hash, :url, :status_code, :content)
    end

    context 'when used on Error crawl results' do
      it 'should include the error in the hash, but not the content' do
        expect(error_crawl_result.to_h).to include(:id, :url_hash, :url, :status_code, :error)
        expect(error_crawl_result.to_h).to_not include(:content)
      end
    end

    context 'when used on a UnsupportedContentType crawl result' do
      it 'should include the error and the content type, but not the content' do
        expect(unsupported_content_type_crawl_result.to_h).to include(:id, :url_hash, :url, :status_code, :error,
                                                                      :content_type)
        expect(unsupported_content_type_crawl_result.to_h).to_not include(:content)
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#to_s' do
    it 'should return a string representation of the object' do
      expect(html_crawl_result.to_s).to be_a(String)
    end

    context 'when used on Error crawl results' do
      it 'should return a string representation of the object' do
        expect(error_crawl_result.to_s).to be_a(String)
      end
    end

    context 'when used on a UnsupportedContentType crawl result' do
      it 'should return a string representation of the object' do
        expect(unsupported_content_type_crawl_result.to_s).to be_a(String)
      end
    end
  end
end
