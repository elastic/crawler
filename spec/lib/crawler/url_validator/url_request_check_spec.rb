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
  let(:http_executor) { double('HttpExecutor') }
  let(:url_crawl_result) do
    double('UrlCrawlResult', status_code: 200, content_type: 'text/html', duration: 0.5, location: nil, error: nil,
                             suggestion_message: nil)
  end
  let(:url_crawl_result_redirect) do
    instance_double('Crawler::Data::CrawlResult::Redirect',
                    redirect?: true,
                    location: Crawler::Data::URL.parse('http://redirected.com'))
  end
  let(:validator) { described_class.new(url: valid_url, crawl_config:) }

  describe '#validate_url_request' do
    before do
      allow(validator).to receive(:http_executor).and_return(http_executor)
      allow(http_executor).to receive(:run).and_return(url_crawl_result)
    end

    context 'when the status code is 200' do
      it 'validates successfully' do
        expect(validator)
          .to receive(:validation_ok)
          .with(:url_request,
                "Successfully fetched #{valid_url}: HTTP 200.",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is 204' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(204) }

      it 'fails validation with no content message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "The Web server at #{valid_url} returned no content (HTTP 204).",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is a redirect (301, 302, 303, 307, 308)' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(301) }

      it 'calls redirect_validation_result' do
        expect(validator).to receive(:redirect_validation_result)
          .with(hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is 401' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(401) }

      it 'calls unauthorized_validation_result' do
        expect(validator).to receive(:unauthorized_validation_result)
          .with(hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is 403' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(403) }

      it 'fails validation with forbidden message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "The web server at #{valid_url} denied us permission to view that page (HTTP 403).\nThis website " \
                "may require a user name and password.\nRead more at: " \
                'https://www.elastic.co/guide/en/enterprise-search/current/crawler-managing.html' \
                "#crawler-managing-authentication.\n",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is 404' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(404) }

      it 'fails validation with not found message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "The web server at #{valid_url} says that there is no web page at that location (HTTP 404).\n",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is 407' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(407) }

      it 'fails validation with proxy authentication required message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "The web server at #{valid_url} is configured to require an HTTP proxy for access (HTTP 407).\n" \
                "This may mean that you're trying to index an internal (intranet) server.\nRead more at: " \
                "https://www.elastic.co/guide/en/enterprise-search/current/crawler-private-network-cloud.html.\n",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is 429' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(429) }

      it 'fails validation with rate limiting message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "The web server at #{valid_url} refused our connection due to request\nrate-limiting (HTTP 429).\n",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is 451' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(451) }

      it 'fails validation with legal reasons message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "The web server at #{valid_url} refused our connection due to legal reasons (HTTP 451).\n",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is between 400 and 499' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(418) }

      it 'fails validation with client error message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "Failed to fetch #{valid_url}: HTTP 418.",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is between 500 and 598' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(500) }

      it 'fails validation with server error message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "Transient error fetching #{valid_url}: HTTP 500.",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is 599' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(599) }
      before { allow(url_crawl_result).to receive(:error).and_return('Some error') }
      before { allow(url_crawl_result).to receive(:suggestion_message).and_return('Some suggestion') }

      it 'fails validation with unexpected error message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "Unexpected error fetching #{valid_url}: Some error.\nSome suggestion\n",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end

    context 'when the status code is unexpected' do
      before { allow(url_crawl_result).to receive(:status_code).and_return(999) }

      it 'fails validation with unexpected status message' do
        expect(validator)
          .to receive(:validation_fail)
          .with(:url_request,
                "Unexpected HTTP status while fetching #{valid_url}: HTTP 999.\n",
                hash_including(:status_code, :content_type, :request_time_msec))
        validator.validate_url_request
      end
    end
  end
end
