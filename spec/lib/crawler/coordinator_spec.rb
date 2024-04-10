# frozen_string_literal: true

RSpec.describe(Crawler::Coordinator) do
  let(:domain) { 'http://example.com' }
  let(:seed_url) { URI.join(domain, '/') }
  let(:seed_urls) { [seed_url] }
  let(:sitemap_url) { URI.join(domain, '/sitemap.xml') }
  let(:sitemap_urls) { [sitemap_url] }

  let(:results_collection) { ResultsCollection.new }
  let(:crawl_configuration) do
    {
      domain_allowlist: [domain],
      seed_urls: seed_urls,
      sitemap_urls: sitemap_urls,
      results_collection: results_collection
    }
  end

  let(:crawl_config) { Crawler::API::Config.new(crawl_configuration) }

  let(:events) { double(:events) }
  let(:system_logger) { Logger.new($stdout, level: :debug) }
  let(:rule_engine) do
    double(
      :rule_engine,
      discover_url_outcome: double(:discover_url_outcome, denied?: false),
      output_crawl_result_outcome: double(:output_crawl_result_outcome, denied?: false)
    )
  end

  let(:sink) { Crawler::OutputSink::Mock.new(crawl_config) }
  let(:crawl_queue) { Crawler::Data::UrlQueue::MemoryOnly.new(crawl_config) }
  let(:seen_urls) { Crawler::Data::SeenUrls.new }

  let(:crawl) do
    double(
      :crawl,
      config: crawl_config,
      events: events,
      system_logger: system_logger,
      rule_engine: rule_engine,
      sink: sink,
      shutdown_started?: false,
      crawl_queue: crawl_queue,
      seen_urls: seen_urls,
      allow_resume?: false
    )
  end
  let(:coordinator) { Crawler::Coordinator.new(crawl) }

  #-------------------------------------------------------------------------------------------------
  describe '#process_crawl_result' do
    let(:url) { Crawler::Data::URL.parse('http://example.com') }
    let(:canonical_link) { nil }
    let(:links) { [] }
    let(:crawl_task) { Crawler::Data::CrawlTask.new(url: url, depth: 1, type: :content) }
    let(:meta_nofollow) { false }
    let(:crawl_result) do
      double(
        :crawl_result,
        url: url,
        canonical_link: canonical_link,
        extract_links: { links: Set.new(links), limit_reached: false },
        meta_nofollow?: meta_nofollow,
        error?: false,
        fatal_error?: false,
        html?: true,
        redirect?: false
      )
    end

    def process_crawl_result
      allow(events).to receive(:url_output)
      allow(events).to receive(:url_discover)
      allow(events).to receive(:url_seed)
      allow(events).to receive(:url_extracted)

      coordinator.send(:process_crawl_result, crawl_task, crawl_result)
    end

    it 'should send the crawl_result to the output sink' do
      expect(crawl.sink).to receive(:write).with(crawl_result).and_call_original
      process_crawl_result
    end

    it 'should generate an url-extracted event' do
      expect(events).to receive(:url_extracted).with(
        hash_including(
          url: crawl_result.url,
          type: :allowed,
          start_time: kind_of(Time),
          end_time: kind_of(Time),
          duration: kind_of(Benchmark::Tms),
          outcome: :success,
          message: 'Successfully ingested crawl result'
        )
      )
      coordinator.send(:process_crawl_result, crawl_task, crawl_result)
    end

    context 'when output sink fails to ingest the result' do
      it 'should generate an url-extracted event based on the ingestion results' do
        expect(crawl.sink).to receive(:write).and_return(crawl.sink.failure('BOOM'))
        expect(events).to receive(:url_extracted).with(
          hash_including(
            url: crawl_result.url,
            type: :allowed,
            start_time: kind_of(Time),
            end_time: kind_of(Time),
            duration: kind_of(Benchmark::Tms),
            outcome: :failure,
            message: 'BOOM'
          )
        )
        coordinator.send(:process_crawl_result, crawl_task, crawl_result)
      end

      it 'should capture exceptions coming from the output module and generate a failure url-extracted event' do
        error = RuntimeError.new('BOOM')
        expect(crawl.sink).to receive(:write).and_raise(error)
        expect(crawl).to receive(:retryable_error?).with(error).and_return(false)
        expect(events).to receive(:url_extracted).with(
          hash_including(
            url: crawl_result.url,
            type: :allowed,
            start_time: kind_of(Time),
            end_time: kind_of(Time),
            duration: kind_of(Benchmark::Tms),
            outcome: :failure,
            message: /BOOM/
          )
        )
        coordinator.send(:process_crawl_result, crawl_task, crawl_result)
      end

      it 'should retry exceptions if possible' do
        error = RuntimeError.new('BOOM')
        expect(crawl.sink).to receive(:write).twice.and_wrap_original do |method, *args|
          unless @called_before
            @called_before = true
            raise error
          end
          method.call(*args)
        end

        expect(crawl).to receive(:retryable_error?).with(error).and_return(true)
        expect(crawl).to receive(:interruptible_sleep)

        expect(events).to receive(:url_extracted).with(
          hash_including(
            url: crawl_result.url,
            type: :allowed,
            start_time: kind_of(Time),
            end_time: kind_of(Time),
            duration: kind_of(Benchmark::Tms),
            outcome: :success,
            message: 'Successfully ingested crawl result'
          )
        )
        coordinator.send(:process_crawl_result, crawl_task, crawl_result)
      end
    end

    context 'when canonical_link is not present' do
      it 'should not add urls to the backlog' do
        expect(coordinator).to_not receive(:add_urls_to_backlog)
        process_crawl_result
      end
    end

    context 'when canonical URL is invalid' do
      let(:canonical_link) { Crawler::Data::Link.new(base_url: url, link: 'foo%:') }
      it 'should not use it' do
        expect(coordinator).to_not receive(:add_urls_to_backlog)
        process_crawl_result
      end
    end

    context 'when extracted links array is empty' do
      it 'should not add urls to the backlog' do
        expect(coordinator).to_not receive(:add_urls_to_backlog)
        process_crawl_result
      end
    end

    context 'when canonical_link is present' do
      let(:canonical_link) { Crawler::Data::Link.new(base_url: url, link: 'http://example.com/canonical') }

      it 'should add the canonical url to the backlog' do
        expect(coordinator).to receive(:add_urls_to_backlog).with(
          urls: [canonical_link.to_url],
          type: :content,
          source_type: :canonical_url,
          source_url: url,
          crawl_depth: crawl_task.depth
        )
        process_crawl_result
      end
    end

    context 'when extracted links array is not empty' do
      let(:links) do
        [
          Crawler::Data::Link.new(base_url: url, link: 'http://example.com/1'),
          Crawler::Data::Link.new(base_url: url, link: 'http://example.com/2')
        ]
      end

      it 'should add the extracted links to the backlog' do
        expect(coordinator).to receive(:add_urls_to_backlog).with(
          urls: links.map(&:to_url),
          type: :content,
          source_type: :organic,
          source_url: url,
          crawl_depth: crawl_task.depth + 1
        )
        process_crawl_result
      end

      context 'when the page contains a meta nofollow tag' do
        let(:meta_nofollow) { true }

        it 'should not add urls to the backlog' do
          allow(events).to receive(:url_discover_denied)
          expect(coordinator).to_not receive(:add_urls_to_backlog)
          process_crawl_result
        end

        it 'should log url_discover events for all the links we are not going to crawl' do
          expect(events).to receive(:url_discover_denied).with(
            hash_including(deny_reason: :nofollow)
          ).exactly(links.count).times
          process_crawl_result
        end
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#add_urls_to_backlog' do
    def add_urls_to_backlog(urls, params = {})
      coordinator.send(
        :add_urls_to_backlog,
        {
          urls: urls,
          type: :content,
          source_type: :organic,
          crawl_depth: 2
        }.merge(params)
      )
    end

    context 'with a unique URLs limit' do
      let(:limit) { 5 }
      let(:crawl_configuration) do
        super().merge(max_unique_url_count: limit)
      end

      it 'should enforce the limit and not add more URLs into the backlog than allowed' do
        urls_count = 9
        urls = (1..urls_count).map { |i| Crawler::Data::URL.parse(seed_url).join("/foo-#{i}") }

        expect(events).to receive(:url_seed).exactly(limit).times
        expect(events).to receive(:url_discover).exactly(limit).times
        expect(events).to receive(:url_discover_denied).with(
          hash_including(
            url: kind_of(Crawler::Data::URL),
            deny_reason: :too_many_unique_links
          )
        ).exactly(urls_count - limit).times

        add_urls_to_backlog(urls)
        expect(crawl_queue.length).to eq(limit)
      end

      it 'should not consider a URL visited if it was denied due to a limit' do
        allow(events).to receive(:url_seed)
        allow(events).to receive(:url_discover)

        # Reach the limit
        upto_limit_urls = (1..limit).map { |i| Crawler::Data::URL.parse(seed_url).join("/foo-#{i}") }
        add_urls_to_backlog(upto_limit_urls)

        # Try to add another one, it should be denied and not be added to the set
        url = Crawler::Data::URL.parse(seed_url).join('/hello')
        expect(events).to receive(:url_discover_denied).with(
          hash_including(
            url: url,
            deny_reason: :too_many_unique_links
          )
        )
        expect { add_urls_to_backlog([url]) }.to_not change { seen_urls.count }
      end
    end

    it 'should deduplicate URLs (using normalized URL versions)' do
      urls = [
        Crawler::Data::URL.parse(seed_url).join('/foo'),
        Crawler::Data::URL.parse(seed_url).join('/bar'),
        Crawler::Data::URL.parse(seed_url).join('/foo'),
        Crawler::Data::URL.parse(seed_url).join('/foo?'),
        Crawler::Data::URL.parse(seed_url).join('/bar'),
        Crawler::Data::URL.parse(seed_url).join('/../../bar')
      ]

      expect(events).to receive(:url_seed).exactly(2).times
      expect(events).to receive(:url_discover).exactly(2).times
      add_urls_to_backlog(urls)
      expect(crawl_queue.length).to eq(2)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#add_url_to_backlog' do
    let(:url) { Crawler::Data::URL.parse(seed_url) }

    def add_url_to_backlog(params = {})
      params = {
        url: url,
        type: :content,
        source_type: :organic,
        crawl_depth: 1,
        source_url: nil
      }.merge(params)
      coordinator.send(:add_url_to_backlog, params)
    end

    context 'when the queue is not full' do
      it 'should record the url-seed event for the the URL' do
        expect(events).to receive(:url_seed).with(
          url: url,
          source_url: nil,
          type: :content,
          crawl_depth: 1,
          source_type: :organic
        )
        add_url_to_backlog
      end

      it 'should enqueue the URL as a crawl task into the queue' do
        allow(events).to receive(:url_seed)
        expect { add_url_to_backlog }.to change { crawl_queue.length }.by(1)
      end
    end

    context 'when the queue is full' do
      before do
        allow(crawl_queue).to receive(:push).and_raise(Crawler::Data::UrlQueue::QueueFullError)
      end

      it 'should not blow up and record the event in the event log instead' do
        expect(events).to receive(:url_discover_denied).with(
          url: url,
          source_url: nil,
          crawl_depth: 1,
          deny_reason: :queue_full
        )
        expect(system_logger).to receive(:debug).with(/Failed to add a crawler task into the processing queue/)
        expect { add_url_to_backlog }.to_not raise_error
      end

      it 'should remove the URL from the seen URLs list' do
        allow(events).to receive(:url_discover_denied)
        allow(system_logger).to receive(:debug)
        expect(seen_urls).to receive(:delete).with(url)
        add_url_to_backlog
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#crawl_finished?' do
    def crawl_finished?
      coordinator.send(:crawl_finished?)
    end

    context 'when the crawl queue is empty' do
      before do
        allow(crawl_queue).to receive(:empty?).and_return(true)
      end

      it 'should return true' do
        expect(crawl_finished?).to be(true)
      end

      it 'should set the outcome' do
        crawl_finished?
        expect(coordinator.crawl_outcome).to eq(:success)
        expect(coordinator.outcome_message).to match(/success/i)
      end
    end

    context 'when the shutdown flag is set' do
      before do
        allow(crawl_queue).to receive(:empty?).and_return(false)
        allow(coordinator.crawl).to receive(:shutdown_started?).and_return(true)
      end

      it 'should return true' do
        expect(crawl_finished?).to be(true)
      end

      it 'should set the outcome' do
        crawl_finished?
        expect(coordinator.crawl_outcome).to eq(:shutdown)
        expect(coordinator.outcome_message).to match(/shutdown/)
      end
    end

    context 'when the crawl hits the max_duration limit' do
      before do
        allow(crawl_queue).to receive(:empty?).and_return(false)
        allow(coordinator.crawl).to receive(:shutdown_started?).and_return(false)
        allow(coordinator).to receive(:crawl_duration).and_return(1.week)
      end

      it 'should return true' do
        expect(crawl_finished?).to be(true)
      end

      it 'should set the outcome' do
        crawl_finished?
        expect(coordinator.crawl_outcome).to eq(:warning)
        expect(coordinator.outcome_message).to match(/max_duration/)
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#check_discovered_url' do
    let(:example_url) { url('http://example.org/') }

    def check_discovered_url(url, type: nil, source_url: nil, crawl_depth: 1)
      coordinator.send(
        :check_discovered_url,
        url: url,
        type: type,
        source_url: source_url,
        crawl_depth: crawl_depth
      )
    end

    def url(url)
      Crawler::Data::URL.parse(url)
    end

    def expect_denied_with_reason(url, reason)
      expect(events).to receive(:url_discover_denied).with(
        hash_including(
          url: url,
          crawl_depth: 1,
          deny_reason: reason
        )
      )
      expect(check_discovered_url(url)).to eq(:deny)
    end

    #-----------------------------------------------------------------------------------------------
    # URL-level limits
    #-----------------------------------------------------------------------------------------------
    it 'should deny non-http(s) URLs' do
      expect_denied_with_reason(url('ftp://warez.com/doom.rar'), :incorrect_protocol)
    end

    it 'should deny URLs that are too long (in characters)' do
      url = url("http://example.org/something?blah=#{'x' * 10_000}")
      expect_denied_with_reason(url, :link_too_long)
    end

    it 'should deny URLs that have too many segments' do
      url = url('http://example.org/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/17')
      expect_denied_with_reason(url, :link_with_too_many_segments)
    end

    it 'should deny URLs that have too many URL params' do
      params = (0..100).map { |x| "p#{x}=x" }.join('&')
      url = url("http://example.org/x?#{params}")
      expect_denied_with_reason(url, :link_with_too_many_params)
    end

    #-----------------------------------------------------------------------------------------------
    # Crawl-level limits, etc
    #-----------------------------------------------------------------------------------------------
    it 'should allow URLs that are at maximum crawl depth' do
      expect(events).to receive(:url_discover).with(
        url: example_url,
        source_url: nil,
        crawl_depth: coordinator.config.max_crawl_depth,
        type: :allowed
      )
      expect(check_discovered_url(example_url, crawl_depth: coordinator.config.max_crawl_depth)).to eq(:allow)
    end

    it 'should deny URLs that lead too deep' do
      expect(events).to receive(:url_discover_denied).with(
        url: example_url,
        source_url: nil,
        crawl_depth: 1000,
        deny_reason: :link_too_deep
      )
      expect(check_discovered_url(example_url, crawl_depth: 1000)).to eq(:deny)
    end

    it 'should deny URLs we have already seen' do
      expect(seen_urls).to receive(:add?).with(example_url).and_return(false)
      expect_denied_with_reason(example_url, :already_seen)
    end

    it 'should deny URLs that the rules engine considers denied' do
      url_outcome = Crawler::Data::DeniedOutcome.new(:rule_engine_denied, message: 'testing')
      expect(coordinator.rule_engine).to receive(:discover_url_outcome).with(example_url).and_return(url_outcome)
      expect(events).to receive(:url_discover_denied).with(
        url: example_url,
        source_url: nil,
        crawl_depth: 1000,
        deny_reason: :rule_engine_denied,
        message: 'testing'
      )
      expect(check_discovered_url(example_url, crawl_depth: 1000)).to eq(:deny)
    end

    it 'should blank-deny URLs after we reach a limit on the number of unique URLs we have seen' do
      allow(seen_urls).to receive(:count).and_return(coordinator.config.max_unique_url_count + 1)
      expect_denied_with_reason(example_url, :too_many_unique_links)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#extract_links' do
    let(:url) { Crawler::Data::URL.parse('http://example.com/') }
    let(:canonical_url) { 'http://example.com/' }
    let(:html) do
      <<~HTML
        <html>
          <body>
            <a href="/hello">Hello</a>
            <a href="/world">World</a>
            <a>Hello without a href</a>
            <a href>Hello from an empty href</a>
            <a href='foo%:'>Hello from a broken link</a>
          </body>
        </html>
      HTML
    end

    let(:crawl_result) do
      Crawler::Data::CrawlResult::HTML.new(
        url: url,
        content: html
      )
    end

    def extract_links(crawl_result, crawl_depth: 1)
      coordinator.send(:extract_links, crawl_result, crawl_depth: crawl_depth)
    end

    it 'should extract valid links' do
      links = extract_links(crawl_result)
      expect(links.count).to eq(3)
    end

    it 'should properly handle cases when we hit the limit on the number of links we can extract' do
      expect(crawl_config).to receive(:max_extracted_links_count).and_return(1)
      links = extract_links(crawl_result)
      expect(links.count).to eq(1)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#enqueue_seed_urls' do
    it 'should emit correct crawl events' do
      expect(events).to receive(:url_discover).exactly(seed_urls.count).times
      expect(events).to receive(:url_seed).exactly(seed_urls.count).times
      expect(events).to receive(:crawl_seed).with(seed_urls.count, type: :content)
      coordinator.send(:enqueue_seed_urls)
    end

    it 'should enqueue seed URLs' do
      allow(events).to receive(:url_discover)
      allow(events).to receive(:url_seed)
      allow(events).to receive(:crawl_seed)

      expect(coordinator).to receive(:add_url_to_backlog).exactly(seed_urls.count).times

      coordinator.send(:enqueue_seed_urls)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#enqueue_sitemaps' do
    let(:robots_sitemap) { "Sitemap: /map.xml'" }
    let(:robots_sitemaps) { [robots_sitemap] }
    let(:robots_txt_content) { "User-agent: *\nAllow: *\n\n#{robots_sitemaps.join("\n\n")}" }
    let(:crawl_result) do
      Crawler::Data::CrawlResult::RobotsTxt.new(
        url: Crawler::Data::URL.parse("#{domain}/robots.txt"),
        status_code: 200,
        content: robots_txt_content
      )
    end

    before do
      crawl_config.robots_txt_service.register_crawl_result(domain, crawl_result)
    end

    context 'default configuration' do
      it 'should emit the correct crawl events and discover sitemaps from robots.txt' do
        sitemaps_count = sitemap_urls.count + robots_sitemaps.count

        expect(events).to receive(:url_discover).exactly(sitemaps_count).times
        expect(events).to receive(:url_seed).exactly(sitemaps_count).times
        expect(events).to receive(:crawl_seed).with(1, type: :content).exactly(2).times
        coordinator.send(:enqueue_sitemaps)
      end
    end

    context 'disable sitemap discovery' do
      let(:crawl_config) { Crawler::API::Config.new(crawl_configuration.merge(sitemap_discovery_disabled: true)) }

      it 'should ignore sitemaps from robots.txt' do
        expect(events).to receive(:url_discover).exactly(sitemap_urls.count).times
        expect(events).to receive(:url_seed).exactly(sitemap_urls.count).times
        expect(events).to receive(:crawl_seed).with(1, type: :content).exactly(1).times
        coordinator.send(:enqueue_sitemaps)
      end
    end
  end
end
