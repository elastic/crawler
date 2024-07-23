#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::RuleEngine::Base) do
  let(:domains) { [{ url: 'http://example.com' }] }
  let(:config) do
    Crawler::API::Config.new(
      domains:,
      robots_txt_service: Crawler::RobotsTxtService.always_allow
    )
  end
  subject(:rule_engine) { described_class.new(config) }

  describe '#discover_url_outcome' do
    it 'should require a domain object' do
      expect do
        rule_engine.discover_url_outcome('google.com')
      end.to raise_error(ArgumentError, 'Needs a Crawler::Data::URL object')
    end

    it 'should allow when a given domain is in the allow list' do
      url = Crawler::Data::URL.parse('http://example.com/something')
      expect(rule_engine.discover_url_outcome(url)).to be_allowed
    end

    it 'should deny when a given domain is not in the allow list' do
      url = Crawler::Data::URL.parse('http://google.com/something')
      expect(rule_engine.discover_url_outcome(url)).to be_denied
    end

    context 'robots.txt' do
      let(:domain) { Crawler::Data::Domain.new('http://example.com') }
      let(:domains) { [{ url: domain.to_s }] }
      let(:config) do
        Crawler::API::Config.new(domains:,
                                 robots_txt_service: @robots_txt_service)
      end

      context 'with crawl delay' do
        before do
          @robots_txt_service = Crawler::RobotsTxtService.new(user_agent: 'Elastic Crawler')
          @robots_txt_service.register_crawl_result(
            domain,
            double(status_code: 200, content: "User-agent: *\nDisallow: /wp-admin\nCrawl-delay: 600")
          )
        end

        it 'allows' do
          url = Crawler::Data::URL.parse('http://example.com/allowed')
          outcome = rule_engine.discover_url_outcome(url)
          expect(outcome).to be_allowed
        end

        it 'disallows' do
          url = Crawler::Data::URL.parse('http://example.com/wp-admin')
          outcome = rule_engine.discover_url_outcome(url)
          expect(outcome).to be_denied
          expect(outcome.message).to eq('Disallowed by robots.txt')
        end
      end

      context 'status 4xx' do
        before do
          @robots_txt_service = Crawler::RobotsTxtService.new(user_agent: 'Elastic Crawler')
          @robots_txt_service.register_crawl_result(domain, double(status_code: 404))
        end

        it 'always allows' do
          url = Crawler::Data::URL.parse('http://example.com/')
          outcome = rule_engine.discover_url_outcome(url)
          expect(outcome).to be_allowed
        end
      end

      context 'status 5xx' do
        before do
          @robots_txt_service = Crawler::RobotsTxtService.new(user_agent: 'Elastic Crawler')
          @robots_txt_service.register_crawl_result(domain, double(status_code: 500))
        end

        it 'never allows' do
          url = Crawler::Data::URL.parse('http://example.com/')
          outcome = rule_engine.discover_url_outcome(url)
          expect(outcome).to be_denied
          expect(outcome.message).to eq('Allow none because robots.txt responded with status 500')
        end
      end
    end

    context 'when the are configured crawl rules' do
      let(:domains) do
        [
          {
            url: 'http://example1.com',
            crawl_rules: [
              { policy: 'deny', pattern: '/foo', type: 'begins' },
              { policy: 'deny', pattern: '/baa', type: 'ends' },
              { policy: 'deny', pattern: '/hmm/', type: 'contains' },
              { policy: 'deny', pattern: '.*/(xaa|xee)/.*', type: 'regex' },
              { policy: 'allow', pattern: '/', type: 'begins' }
            ]
          }
        ]
      end

      [
        # 'begins' rule
        'http://example1.com/foo',
        'http://example1.com/foo/1',
        'http://example1.com/foo/1/2',
        # 'ends' rule
        'http://example1.com/baa',
        'http://example1.com/1/baa',
        'http://example1.com/1/2/baa',
        # 'contains' rule
        'http://example1.com/1/hmm/2',
        'http://example1.com/1/2/hmm/3/4',
        'http://example1.com/hmm/1/2',
        # 'regex' rule
        'http://example1.com/1/xaa/2',
        'http://example1.com/1/2/xaa/3/4',
        'http://example1.com/xaa/1/2',
        'http://example1.com/1/xee/2',
        'http://example1.com/1/2/xee/3',
        'http://example1.com/xee/1'
      ].each do |url_string|
        it "should deny the URL #{url_string}" do
          url = Crawler::Data::URL.parse(url_string)
          expect(rule_engine.discover_url_outcome(url)).to be_denied
        end
      end

      [
        'http://example1.com/',
        'http://example1.com/baa/foo',
        'http://example1.com/hmm', # no trailing slash
        'http://example1.com/xee' # no trailing slash
      ].each do |url_string|
        it "should allow the URL #{url_string}" do
          url = Crawler::Data::URL.parse(url_string)
          expect(rule_engine.discover_url_outcome(url)).to be_allowed
        end
      end
    end
  end

  describe '#output_crawl_result_outcome' do
    let(:url) { Crawler::Data::URL.parse('http://example.com/') }
    let(:outcome) { rule_engine.output_crawl_result_outcome(mock_crawl_result) }

    context 'noindex meta tag' do
      let(:mock_crawl_result) do
        Crawler::Data::CrawlResult::HTML.new(
          url:,
          content: '<html><head><meta name="robots" content="noindex"></head><body><a href="http://example.com/link"></a></body></html>'
        )
      end

      it 'should deny' do
        expect(outcome).to be_denied
      end
    end

    context 'noindex and nofollow meta tag' do
      let(:mock_crawl_result) do
        Crawler::Data::CrawlResult::HTML.new(
          url:,
          content: '<html><head><meta name="robots" content="noindex, nofollow"></head><body><a href="http://example.com/link"></a></body></html>'
        )
      end

      it 'should deny' do
        expect(outcome).to be_denied
      end
    end

    context 'for a fatal error response' do
      let(:mock_crawl_result) do
        Crawler::Data::CrawlResult::Error.new(
          url:,
          error: 'Something went horribly wrong'
        )
      end

      it 'should deny' do
        expect(outcome).to be_denied
      end
    end

    context 'for a response for an unsupported content type' do
      let(:mock_crawl_result) do
        Crawler::Data::CrawlResult::UnsupportedContentType.new(
          url:,
          status_code: 200,
          content_type: 'application/java'
        )
      end

      it 'should deny' do
        expect(outcome).to be_denied
      end
    end

    context 'ok to index page' do
      let(:mock_crawl_result) do
        Crawler::Data::CrawlResult::HTML.new(
          url:,
          content: '<html><body><a href="http://example.com/link"></a></body></html>'
        )
      end

      it 'should allow' do
        expect(outcome).to be_allowed
      end
    end
  end
end
