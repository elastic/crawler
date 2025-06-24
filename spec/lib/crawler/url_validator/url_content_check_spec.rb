#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::UrlValidator) do
  let(:valid_url) { Crawler::Data::URL.parse('http://example.com') }
  let(:domain_allowlist) { ['example.com'] }
  let(:crawl_config) { double('CrawlConfig', domain_allowlist:) }
  let(:validator) { described_class.new(url: valid_url, crawl_config:) }
  let(:url) { Crawler::Data::URL.parse(valid_url) }
  let(:content) do
    <<~HTML
      <html>
        <head>
          <title>Title</title>
          <meta name="keywords" content="Keywords">
          <meta name="description" content="Description">
        </head>
        <body>
          Some content
          <a href="http://example.com/link1">Link1</a>
          <a href="http://example.com/link2">Link2</a>
        </body>
      </html>
    HTML
  end
  let(:url_crawl_result_html) { Crawler::Data::CrawlResult::HTML.new(status_code: 200, content:, url:) }
  let(:url_crawl_result_error) do
    Crawler::Data::CrawlResult::Error.new(url:, suggestion_message: 'suggestion message', error: 'error')
  end
  let(:url_crawl_result_redirect) do
    instance_double('Crawler::Data::CrawlResult::Redirect',
                    redirect?: true,
                    location: 'http://redirected.com')
  end
  let(:url_crawl_result_redirect_error) do
    instance_double('Crawler::Data::CrawlResult::RedirectError',
                    redirect?: false,
                    suggestion_message: 'suggestion message',
                    content_type: 'unknown')
  end
  let(:crawler_api_config) do
    instance_double('CrawlConfig',
                    max_title_size: 100,
                    max_keywords_size: 100,
                    max_description_size: 100)
  end

  describe '#validate_url_content' do
    before do
      validator.singleton_class.include(Crawler::UrlValidator::UrlContentCheckConcern)
      allow(validator).to receive(:crawler_api_config).and_return(crawler_api_config)
      allow(validator).to receive(:validate_url_request)
      allow(validator).to receive(:validation_ok)
      allow(validator).to receive(:validation_warn)
      allow(validator).to receive(:validation_fail)
    end

    context 'when URL content is HTML but body is empty' do
      let(:content) { '<html><head><title>Title</title></head><body></body></html>' }

      before do
        allow(validator).to receive(:url_crawl_result).and_return(url_crawl_result_html)
      end

      it 'calls validation_warn with the correct parameters' do
        validator.validate_url_content(crawl_config)
        expect(validator)
          .to have_received(:validation_warn)
          .with(:url_content, "The web page at #{validator.url} did not return enough content to index.")
      end
    end

    context 'when URL content is HTML and body is not empty' do
      before do
        allow(validator).to receive(:url_crawl_result).and_return(url_crawl_result_html)
      end

      it 'calls validation_ok with follow' do
        validator.validate_url_content(crawl_config)
        expect(validator).to have_received(:validation_ok).twice
      end
    end

    context 'when there are links in the content' do
      before do
        allow(validator).to receive(:url_crawl_result).and_return(url_crawl_result_html)
      end

      it 'calls validation_ok with the correct parameters for links' do
        validator.validate_url_content(crawl_config)
        expect(validator).to have_received(:validation_ok).with(
          :url_content,
          "Successfully extracted some links from #{validator.url}.",
          links_sample: ['http://example.com/link1', 'http://example.com/link2']
        )
      end
    end

    context 'when there are no links in the content' do
      let(:content) { '<html><head><title>Title</title></head><body>Some content</body></html>' }

      before do
        allow(validator).to receive(:url_crawl_result).and_return(url_crawl_result_html)
      end

      it 'calls validation_warn with the correct parameters for no links' do
        validator.validate_url_content(crawl_config)
        expect(validator).to have_received(:validation_warn).with(
          :url_content,
          /The web page at #{validator.url} has no links in it at all/
        )
      end
    end

    context 'when URL is redirected' do
      before do
        allow(validator).to receive(:url_crawl_result).and_return(url_crawl_result_redirect)
      end

      it 'calls validation_warn_from_crawl_redirect' do
        expect(validator).to receive(:validation_warn_from_crawl_redirect)
        validator.validate_url_content(crawl_config)
      end

      it 'calls validation_warn with the correct parameters' do
        validator.validate_url_content(crawl_config)
        expect(validator).to have_received(:validation_warn).with(
          :url_content,
          "The web page at #{validator.url} redirected us to http://redirected.com,\nplease make sure the " \
          "destination page contains some indexable\ncontent and is allowed by crawl rules before starting " \
          "your crawl.\n",
          location: 'http://redirected.com'
        )
      end

      context 'when validation_fail_from_crawl_error with redirect error' do
        before do
          allow(validator).to receive(:url_crawl_result).and_return(url_crawl_result_redirect_error)
        end

        it 'calls validation_fail_from_crawl_error with redirect error result' do
          validator.validate_url_content(crawl_config)
          expect(validator).to have_received(:validation_fail).with(
            :url_content,
            "When we fetched the web page at #{validator.url}, the server returned data that was not HTML.\n" \
            "suggestion message\n",
            content_type: 'unknown'
          )
        end
      end
    end

    context 'when validation_fail_from_crawl_error' do
      before do
        allow(validator).to receive(:url_crawl_result).and_return(url_crawl_result_error)
      end

      it 'calls validation_fail_from_crawl_error with crawl error' do
        validator.validate_url_content(crawl_config)
        expect(validator).to have_received(:validation_fail).with(
          :url_content,
          "When we fetched the web page at #{validator.url}, an unexpected error occurred: error.\n" \
          "suggestion message\n",
          content_type: 'unknown'
        )
      end
    end
  end
end
