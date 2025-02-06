#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::API::Crawl) do
  let(:url) { 'http://example.com' }
  let(:parsed_url) { Crawler::Data::URL.parse(url) }

  let(:crawl_config) do
    Crawler::API::Config.new(
      domains: [
        { url: }
      ],
      output_sink: :elasticsearch,
      output_index: 'some-index-name',
      elasticsearch: {
        host: 'http://localhost',
        port: 1234,
        api_key: 'key'
      }
    )
  end

  let(:mock_seed_body) { '<html><body><a href="http://example.com/link"></a></body></html>' }
  let(:mock_crawl_result) do
    Crawler::Data::CrawlResult::HTML.new(
      url: parsed_url,
      content: mock_seed_body
    )
  end
  let(:executor) { Crawler::MockExecutor.new(url => mock_crawl_result) }

  let(:es_client) { double }
  let(:es_client_indices) { double(:es_client_indices, exists: double) }
  let(:build_info) { { version: { number: "8.99.0", build_flavor: "default" } }.deep_stringify_keys }

  subject do
    described_class.new(crawl_config).tap do |crawl|
      crawl.executor = executor
    end
  end

  before do
    # Replace the event logger with a fake one to capture logged events
    crawl_config.instance_variable_set(:@event_logger, Crawler::MockEventLogger.new)

    allow(ES::Client).to receive(:new).and_return(es_client)
    allow(es_client).to receive(:indices).and_return(es_client_indices)
    allow(es_client).to receive(:info).and_return(build_info)
  end

  #-------------------------------------------------------------------------------------------------
  it 'has a config' do
    expect(subject.config.seed_urls.map(&:to_s).to_a).to eq(["#{url}/"])
    expect(subject.config.output_sink).to eq(:elasticsearch)
  end

  it 'has a output sink' do
    expect(subject.sink).to be_a(Crawler::OutputSink::Base)
  end

  it 'starts without error' do
    expect { subject.start! }.to_not raise_error
    expect(subject.config.event_logger.mock_events).to include(
      hash_including('event.action' => 'crawl-start'),
      hash_including('event.action' => 'crawl-end')
    )
  end

  #-------------------------------------------------------------------------------------------------
  context 'after a successful crawl' do
    it 'should release URL queue resources' do
      expect(subject.crawl_queue).to receive(:delete)
      subject.start!
    end

    it 'should release SeenUrls resources' do
      expect(subject.seen_urls).to receive(:clear)
      subject.start!
    end

    it 'should emit an appropriate form of the crawl-end event' do
      subject.start!
      expect(subject.config.event_logger.mock_events).to include(
        hash_including(
          'event.action' => 'crawl-end',
          'event.outcome' => 'success',
          'crawler.crawl.resume_possible' => false
        )
      )
    end
  end

  #-------------------------------------------------------------------------------------------------
  context 'if the crawl is shut down prematurely' do
    let(:allow_resume) { false }
    before do
      subject.start_shutdown!(
        reason: 'testing',
        allow_resume:
      )
    end

    it 'should emit an appropriate form of the crawl-end event' do
      subject.start!
      expect(subject.config.event_logger.mock_events).to include(
        hash_including(
          'event.action' => 'crawl-end',
          'event.outcome' => 'shutdown',
          'crawler.crawl.resume_possible' => false
        )
      )
    end

    it 'should release URL queue and SeenUrls resources' do
      expect(subject.seen_urls).to receive(:clear)
      expect(subject.crawl_queue).to receive(:delete)
      subject.start!
    end

    context 'with resume allowed' do
      let(:allow_resume) { true }

      it 'should save the state' do
        expect(subject.crawl_queue).to receive(:save)
        expect(subject.seen_urls).to receive(:save)
        subject.start!
      end

      it 'should emit an appropriate form of the crawl-end event' do
        subject.start!
        expect(subject.config.event_logger.mock_events).to include(
          hash_including(
            'event.action' => 'crawl-end',
            'event.outcome' => 'shutdown',
            'crawler.crawl.resume_possible' => true
          )
        )
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  context 'when resuming a crawl' do
    let(:url) { Crawler::Data::URL.parse('http://example.com') }
    let(:crawl_task) do
      Crawler::Data::CrawlTask.new(url:, depth: 1, type: :content)
    end

    before do
      subject.crawl_queue.push(crawl_task)
      subject.seen_urls.add?(url)
    end

    it 'should emit a crawl-start event with crawler.crawl.resume = true' do
      subject.start!
      expect(subject.config.event_logger.mock_events).to include(
        hash_including('event.action' => 'crawl-start', 'crawler.crawl.resume' => true)
      )
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#status' do
    it 'should return status info for the crawl' do
      expect(subject.status).to include(
        :queue_size,
        :pages_visited,
        :urls_allowed,
        :urls_denied,
        :crawl_duration_msec,
        :crawling_time_msec,
        :avg_response_time_msec,
        :active_threads,
        :http_client,
        :status_codes
      )
    end
  end
end
