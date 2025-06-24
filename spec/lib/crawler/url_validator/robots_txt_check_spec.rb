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
  let(:crawl_task) { instance_double('Crawler::Data::CrawlTask') }
  let(:http_executor) { double('HttpExecutor') }
  let(:crawler_api_config) { double('CrawlerApiConfig', user_agent: 'TestAgent') }
  let(:crawl_result) do
    Crawler::Data::CrawlResult::Error.new(url: Crawler::Data::URL.parse(valid_url), error: 'error', status_code: 500)
  end

  describe '#validate_robots_txt' do
    before do
      allow(validator).to receive(:http_executor).and_return(http_executor)
      allow(validator).to receive(:crawler_api_config).and_return(crawler_api_config)
      allow(Crawler::Data::CrawlTask).to receive(:new).and_return(crawl_task)
      allow(http_executor).to receive(:run).with(crawl_task, follow_redirects: true).and_return(crawl_result)
      allow(validator).to receive(:validation_warn)
      allow(validator).to receive(:validation_ok)
      allow(validator).to receive(:validation_fail)
    end

    context 'when there is a redirect error' do
      before do
        allow(crawl_result).to receive(:is_a?).with(Crawler::Data::CrawlResult::RedirectError).and_return(true)
        allow(crawl_result).to receive(:error).and_return('Redirect error')
      end

      it 'returns a validation warning' do
        expect(validator).to receive(:validation_warn).with(:robots_txt, /redirect error/)
        validator.validate_robots_txt(crawl_config)
      end
    end

    context 'when robots.txt is not found (404)' do
      before do
        allow(crawl_result).to receive(:status_code).and_return(404)
      end

      it 'returns validation ok' do
        expect(validator).to receive(:validation_ok).with(:robots_txt, /No robots.txt found/)
        validator.validate_robots_txt(crawl_config)
      end
    end

    context 'when there is an internal error (599)' do
      before do
        allow(crawl_result).to receive(:status_code).and_return(599)
        allow(crawl_result).to receive(:error).and_return('Internal error')
        allow(crawl_result).to receive(:suggestion_message).and_return('Suggestion')
      end

      it 'returns a validation failure' do
        expect(validator).to receive(:validation_fail).with(:robots_txt, /Failed to fetch robots.txt/)
        validator.validate_robots_txt(crawl_config)
      end
    end

    context 'when there is a transient error (>= 500)' do
      before do
        allow(crawl_result).to receive(:status_code).and_return(500)
      end

      it 'returns a validation failure' do
        expect(validator).to receive(:validation_fail).with(:robots_txt, /Transient error fetching robots.txt/)
        validator.validate_robots_txt(crawl_config)
      end
    end

    context 'when robots.txt is fetched successfully' do
      let(:robots_txt_service) { instance_double('Crawler::RobotsTxtService') }
      let(:robots_txt_parser) { instance_double('RobotsTxtParser') }
      let(:robots_outcome) { instance_double('RobotsOutcome') }

      before do
        allow(crawl_result).to receive(:status_code).and_return(200)
        allow(Crawler::RobotsTxtService).to receive(:new).and_return(robots_txt_service)
        allow(robots_txt_service).to receive(:register_crawl_result)
        allow(robots_txt_service).to receive(:parser_for_domain).and_return(robots_txt_parser)
        allow(robots_txt_parser).to receive(:allow_all?).and_return(false)
        allow(robots_txt_service).to receive(:url_disallowed_outcome).and_return(robots_outcome)
      end

      context 'when robots.txt allows full access' do
        before do
          allow(robots_txt_parser).to receive(:allow_all?).and_return(true)
        end

        it 'returns validation ok' do
          expect(validator).to receive(:validation_ok).with(:robots_txt, /allows us full access/)
          validator.validate_robots_txt(crawl_config)
        end
      end

      context 'when robots.txt allows partial access' do
        before do
          allow(robots_outcome).to receive(:allowed?).and_return(true)
        end

        it 'returns a validation warning' do
          expect(validator).to receive(:validation_warn).with(:robots_txt,
                                                              /allows us access to the domain with some restrictions/)
          validator.validate_robots_txt(crawl_config)
        end
      end

      context 'when robots.txt disallows access' do
        before do
          allow(robots_outcome).to receive(:allowed?).and_return(false)
          allow(robots_outcome).to receive(:disallow_message).and_return('Disallow message')
        end

        it 'returns a validation failure' do
          expect(validator).to receive(:validation_fail).with(:robots_txt, /disallows us access/)
          validator.validate_robots_txt(crawl_config)
        end
      end
    end
  end
end
