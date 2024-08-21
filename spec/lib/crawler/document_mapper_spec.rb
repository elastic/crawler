#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::DocumentMapper) do
  let(:subject) { described_class.new(config) }
  let(:url) { Crawler::Data::URL.parse('https://example.com') }
  let(:config_params) { { domains: [{ url: url.to_s }] } }
  let(:config) { Crawler::API::Config.new(config_params) }

  describe '#create_doc' do
    context 'when crawl result is HTML' do
      let(:meta_description) { 'An apt description!' }
      let(:meta_keywords) { 'foo, faa, fee' }
      let(:title) { 'A website!' }
      let(:link1) { '/link1' }
      let(:link2) { '/link2' }
      let(:heading1) { 'Main heading' }
      let(:heading2) { 'Subheading' }
      let(:content) do
        <<~HTML
          <html>
            <head>
              <meta name="description" content="#{meta_description}">
              <meta name="keywords" content="#{meta_keywords}">
            </head>
            <body>
              <title>#{title}</title>
              <h1>#{heading1}</h1>
              <h2>#{heading2}</h2>
              <a href="#{link1}">Hello</a>
              <a href="#{link2}">Goodbye</a>
              <p class="chosen">Chosen 1</p>
              <div class="chosen">Chosen 2</div>
            </body>
          </html>
        HTML
      end
      let(:crawl_result) { FactoryBot.build(:html_crawl_result, url:, content:) }
      let(:expected_result) do
        {
          id: crawl_result.url_hash,
          last_crawled_at: crawl_result.start_time.rfc3339,
          title:,
          body: crawl_result.document_body,
          meta_keywords:,
          meta_description:,
          links: %W[#{url}#{link1} #{url}#{link2}],
          headings: [heading1, heading2],
          url: url.to_s,
          url_scheme: url.scheme,
          url_host: url.host,
          url_port: url.inferred_port
        }
      end

      it 'creates a doc with HTML fields' do
        result = subject.create_doc(crawl_result)

        expect(result).to eq(expected_result)
      end

      context 'when extraction rules are present' do
        let(:config_params) do
          {
            domains: [
              {
                url: url.to_s,
                extraction_rulesets: [
                  {
                    url_filters: [{ type: 'regex', pattern: '.*' }],
                    rules: [
                      {
                        action: 'extract',
                        field_name: 'chosen_fields',
                        selector: '.chosen',
                        join_as: 'array',
                        source: 'html'
                      }
                    ]
                  }
                ]
              }
            ]
          }
        end

        let(:expected_result_extracted) do
          expected_result.merge(
            chosen_fields: ['Chosen 1', 'Chosen 2']
          )
        end

        it 'creates a doc with HTML fields and custom extracted fields' do
          result = subject.create_doc(crawl_result)

          expect(result).to eq(expected_result_extracted)
        end
      end

      context 'when config limits the size of fields' do
        let(:config_params) do
          {
            domains: [{ url: url.to_s }],
            max_title_size: 5,
            max_body_size: 10,
            max_keywords_size: 10,
            max_description_size: 10,
            max_indexed_links_count: 1,
            max_headings_count: 1
          }
        end
        let(:expected_result_limited) do
          expected_result.merge(
            title: 'A …',
            body: 'A websi…',
            meta_keywords: 'foo, fa…',
            meta_description: 'An apt …',
            links: ["#{url}#{link1}"],
            headings: [heading1]
          )
        end

        it 'creates an doc with HTML fields properly limited' do
          result = subject.create_doc(crawl_result)

          expect(result).to eq(expected_result_limited)
        end
      end
    end

    context 'when crawl result is a binary file' do
      let(:content_length) { 500 }
      let(:content_type) { 'application/pdf' }
      let(:content) { 'A PDF for ants' }
      let(:file_name) { 'ant-file.pdf' }
      let(:file_url) { Crawler::Data::URL.parse("https://example.com/#{file_name}") }
      let(:crawl_result) do
        FactoryBot.build(:content_extractable_file_crawl_result, content:, content_length:, content_type:,
                                                                 url: file_url.to_s)
      end

      let(:expected_result) do
        {
          id: crawl_result.url_hash,
          last_crawled_at: crawl_result.start_time.rfc3339,
          file_name:,
          content_length:,
          content_type:,
          _attachment: crawl_result.base64_encoded_content,
          url: file_url.to_s,
          url_scheme: file_url.scheme,
          url_host: file_url.host,
          url_port: file_url.inferred_port,
          url_path: "/#{file_name}",
          url_path_dir1: file_name
        }
      end

      it 'creates a doc with binary file fields' do
        result = subject.create_doc(crawl_result)

        expect(result).to eq(expected_result)
      end

      context 'when extraction rules are present' do
        let(:config_params) do
          {
            domains: [
              {
                url: url.to_s,
                extraction_rulesets: [
                  {
                    url_filters: [{ type: 'regex', pattern: '.*' }],
                    rules: [
                      {
                        action: 'set',
                        field_name: 'is_pdf',
                        selector: '(?i)^.*\.pdf$',
                        value: 'yes',
                        source: 'url'
                      }
                    ]
                  }
                ]
              }
            ]
          }
        end

        let(:expected_result_extracted) do
          expected_result.merge(
            is_pdf: 'yes'
          )
        end

        it 'creates a doc with binary content content fields and custom extracted fields' do
          result = subject.create_doc(crawl_result)

          expect(result).to eq(expected_result_extracted)
        end
      end
    end

    context 'when crawl result type is unsupported' do
      let(:crawl_result) { FactoryBot.build(:robots_crawl_result) }

      it 'should raise an error' do
        expect { subject.create_doc(crawl_result) }
          .to raise_error(Crawler::DocumentMapper::UnsupportedCrawlResultError)
      end
    end
  end
end
