#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::ContentEngine::Extractor) do
  let(:domain) { 'http://example.com' }
  let(:html) do
    <<~HTML
      <html>
        <head>©
          <title>Under construction...</title>
          <link rel="canonical" href="#{domain}/canonical" />
          <meta name="keywords" content="keywords, stuffing, SEO" />
          <meta name="description" content="The best site in the universe!" />
        </head>
        <body>
          Hello, World!
          <div id="need_to_be_extracted"> Random container </div>
        <body>
      </html>
    HTML
  end
  let(:html_crawl_result) do
    Crawler::Data::CrawlResult::HTML.new(
      url: Crawler::Data::URL.parse("#{domain}/foo/faa/fum"),
      content: html
    )
  end

  let(:set_field_config) do
    [
      {
        action: 'set',
        field_name: 'set_html_field',
        selector: '#need_to_be_extracted',
        source: 'html',
        value: 'set_html_value'
      },
      {
        action: 'set',
        field_name: 'set_url_field',
        selector: 'foo\/([a-zA-Z0-9]{3})',
        source: 'url',
        value: 'set_url_value'
      }
    ]
  end
  let(:extract_field_config) do
    [
      {
        action: 'extract',
        field_name: 'extracted_html_field',
        join_as: 'string',
        selector: '#need_to_be_extracted',
        source: 'html'
      },
      {
        action: 'extract',
        field_name: 'extracted_url_field',
        join_as: 'string',
        selector: 'foo\/([a-zA-Z0-9]{3})',
        source: 'url'
      }
    ]
  end
  let(:url_filters) do
    [{
      type: 'begins',
      pattern: '/'
    }]
  end
  let(:extract_ruleset_config) do
    {
      rules: extract_field_config,
      url_filters:
    }
  end
  let(:set_ruleset_config) do
    {
      rules: set_field_config,
      url_filters:
    }
  end

  let(:ruleset) { Crawler::Data::Extraction::Ruleset.new(ruleset_config_payload, domain) }

  describe '#extract' do
    subject { described_class.extract([ruleset], html_crawl_result) }

    context 'when value type is `set`' do
      let(:ruleset_config_payload) { set_ruleset_config }

      it 'should have set values' do
        expect(subject).to match('set_html_field' => 'set_html_value', 'set_url_field' => 'set_url_value')
      end
    end

    context 'when value type is `extract`' do
      let(:ruleset_config_payload) { extract_ruleset_config }

      it 'should have extracted values' do
        expect(subject).to match('extracted_html_field' => 'Random container', 'extracted_url_field' => 'faa')
      end
    end

    context 'when ruleset has multiple rules' do
      let(:ruleset_config_payload) do
        {
          rules: set_field_config + extract_field_config,
          url_filters:
        }
      end

      it 'should have both set and extracted values' do
        expect(subject).to match(
          'set_html_field' => 'set_html_value',
          'set_url_field' => 'set_url_value',
          'extracted_html_field' => 'Random container',
          'extracted_url_field' => 'faa'
        )
      end
    end

    context 'when selector does not find anything' do
      let(:extract_field_config) do
        [
          {
            action: 'extract',
            field_name: 'extracted_value_field',
            join_as: 'string',
            selector: '#doesnt_exist',
            source: 'html'
          },
          {
            action: 'extract',
            field_name: 'extracted_url_field',
            join_as: 'string',
            selector: 'baa\/([a-zA-Z0-9]{3})',
            source: 'url'
          }
        ]
      end
      let(:ruleset_config_payload) { extract_ruleset_config }

      it 'should have an extracted value' do
        expect(subject).to match('extracted_value_field' => '', 'extracted_url_field' => '')
      end
    end

    context 'when join_as is `array`' do
      let(:ruleset_config_payload) do
        {
          rules: [
            {
              action: 'extract',
              field_name: 'extracted_value_field_array',
              join_as: 'array',
              selector: '#need_to_be_extracted',
              source: 'html'
            },
            {
              action: 'extract',
              field_name: 'extracted_url_field_array',
              join_as: 'array',
              selector: 'foo\/([a-zA-Z0-9]{3})',
              source: 'url'
            }
          ],
          url_filters:
        }
      end

      it 'should concatenate the results as an array' do
        expect(subject).to match(
          'extracted_value_field_array' => ['Random container'],
          'extracted_url_field_array' => ['faa']
        )
      end
    end

    context 'when url_filters discard all URLs' do
      let(:url_filters) do
        [{
          type: 'begins',
          pattern: '/does_not_exist'
        }]
      end
      let(:ruleset_config_payload) do
        {
          rules: set_field_config + extract_field_config,
          url_filters:
        }
      end

      it 'should return an empty object' do
        expect(subject).to be_empty
      end
    end

    context 'when url_filters are empty' do
      let(:url_filters) { [] }
      let(:ruleset_config_payload) { set_ruleset_config }

      it 'should apply any rules' do
        expect(subject).to match('set_html_field' => 'set_html_value', 'set_url_field' => 'set_url_value')
      end
    end
  end
end
