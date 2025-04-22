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
      let(:meta_tag_number) { '0451' }
      let(:meta_tag_string) { 'elastician' }
      let(:body_data_attr_one) { 'Elasticize' }
      let(:body_data_attr_two) { 'ELK' }
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
              <meta class="elastic" name="number_value_tag" content="#{meta_tag_number}">
              <meta class="elastic" name="string_value_tag" content="#{meta_tag_string}">
            </head>
            <body>
              <title>#{title}</title>
              <h1>#{heading1}</h1>
              <h2>#{heading2}</h2>
              <a href="#{link1}">Hello</a>
              <a href="#{link2}">Goodbye</a>
              <p class="chosen">Chosen 1</p>
              <div class="chosen">Chosen 2</div>
              <div data-elastic-name="in_body_tag">#{body_data_attr_one}</div>
              <div data-elastic-name="in_body_tag_two">#{body_data_attr_two}</div>
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
          number_value_tag: meta_tag_number,
          string_value_tag: meta_tag_string,
          in_body_tag: body_data_attr_one,
          in_body_tag_two: body_data_attr_two,
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

      context 'when full HTML extraction is enabled' do
        let(:config_params) do
          {
            domains: [{ url: url.to_s }],
            full_html_extraction_enabled: true
          }
        end
        let(:expected_result_extracted) do
          expected_result.merge(
            full_html: Nokogiri::HTML(content).inner_html
          )
        end

        it 'includes the full HTML in the result' do
          result = subject.create_doc(crawl_result)

          expect(result).to eq(expected_result_extracted)
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

  describe 'URL Rewriting' do
    let(:site_url_str) { 'https://original.com' }
    let(:site_url) { Crawler::Data::URL.parse(site_url_str) }
    let(:rewrite_target) { 'https://rewritten.com' }
    let(:config_params) do
      {
        domains: [{ url: site_url_str, rewrite: rewrite_target }] # Basic domain config
      }
    end

    describe '#rewrite_url' do
      context 'when a matching rewrite rule exists' do
        it 'rewrites a URL starting with the site URL' do
          original_url = "#{site_url_str}/path/page.html"
          expected_url = "#{rewrite_target}/path/page.html"
          rewritten = subject.send(:rewrite_url, site_url, original_url)
          expect(rewritten.to_s).to eq(expected_url)
        end

        it 'does not rewrite a URL that does not start with the site URL' do
          original_url = "https://another-domain.com/path/page.html"
          rewritten = subject.send(:rewrite_url, site_url, original_url)
          expect(rewritten.to_s).to eq(original_url) # Should be unchanged
        end

        it 'handles URL objects as input' do
          original_url_obj = Crawler::Data::URL.parse("#{site_url_str}/path/page.html")
          expected_url = "#{rewrite_target}/path/page.html"
          rewritten = subject.send(:rewrite_url, site_url, original_url_obj)
          expect(rewritten.to_s).to eq(expected_url)
        end
      end

      context 'when no matching rewrite rule exists' do
        let(:config_params) { { domains: [{ url: site_url_str }] } } # No rewrite_rules

        it 'returns the original URL' do
          original_url = "#{site_url_str}/path/page.html"
          rewritten = subject.send(:rewrite_url, site_url, original_url)
          expect(rewritten.to_s).to eq(original_url)
        end
      end

      context 'when rewrite rules are empty' do
        let(:config_params) { { domains: [{ url: site_url_str }], rewrite_rules: {} } }

        it 'returns the original URL' do
          original_url = "#{site_url_str}/path/page.html"
          rewritten = subject.send(:rewrite_url, site_url, original_url)
          expect(rewritten.to_s).to eq(original_url)
        end
      end
    end

    describe '#rewrite_links' do
      # Use the correct constant HTML
      let(:crawl_result) { instance_double(Crawler::Data::CrawlResult::HTML) }
      let(:original_links_array) do
        [
          "#{site_url_str}/page1",
          "#{site_url_str}/another/page2",
          'https://unrelated.com/page3', # Should not be rewritten
          'http://original.com/page4'    # Different scheme, should not match site_url_str key
        ]
      end
      let(:expected_rewritten_links) do
        [
          "#{rewrite_target}/page1",
          "#{rewrite_target}/another/page2",
          'https://unrelated.com/page3',
          'http://original.com/page4'
        ]
      end

      before do
        # Stub the methods called on crawl_result within rewrite_links
        allow(crawl_result).to receive(:site_url).and_return(site_url)
        # Stub the links method to return our controlled array, bypassing its internal logic/limit
        allow(crawl_result).to receive(:links).and_return(original_links_array)
        # Stub url method used only for logging
        allow(crawl_result).to receive(:url).and_return('https://original.com/source_page')
      end

      context 'when rewrite rules are defined' do
        it 'returns a new array with links rewritten according to rules' do
          rewritten = subject.send(:rewrite_links, crawl_result)

          expect(rewritten).to eq(expected_rewritten_links)
        end

        it 'does not modify the original array returned by crawl_result.links' do
          original_links_array_copy = original_links_array.dup
          allow(crawl_result).to receive(:links).and_return(original_links_array_copy)

          subject.send(:rewrite_links, crawl_result)
          expect(original_links_array_copy).to eq(original_links_array)
        end
      end

      context 'when no rewrite rules are defined' do
        let(:config_params) { { domains: [{ url: site_url_str }] } }

        it 'returns an array identical to the original links' do
          rewritten = subject.send(:rewrite_links, crawl_result)
          expect(rewritten).to eq(original_links_array)
        end
      end
    end
  end
end
