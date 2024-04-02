# frozen_string_literal: true

RSpec.describe(Crawler::EventGenerator) do
  let(:domains) { ['http://example.com'] }
  let(:seed_urls) { ['http://example.com/'] }
  let(:config) do
    Crawler::API::Config.new(
      :domain_allowlist => domains,
      :seed_urls => seed_urls
    )
  end

  let(:events) { Crawler::EventGenerator.new(config) }

  describe '#log_crawl_status' do
    let(:crawl) { double(:crawl) }

    it 'should generate a crawl-status event' do
      expect(events).to receive(:crawl_status)
      events.log_crawl_status(crawl)
    end

    it 'should only log once per stats_dump_interval' do
      allow(config).to receive(:stats_dump_interval).and_return(1)
      expect(events).to receive(:crawl_status).exactly(2).times

      events.log_crawl_status(crawl) # should get logged
      events.log_crawl_status(crawl) # should get silenced
      sleep(config.stats_dump_interval)
      events.log_crawl_status(crawl) # should get logged again
    end

    it 'should ignore the stats dump interval if called with force: true' do
      expect(events).to receive(:crawl_status).exactly(2).times
      events.log_crawl_status(crawl)
      events.log_crawl_status(crawl, :force => true)
    end
  end

  describe '#log_error' do
    context 'with backtrace' do
      it 'should generate an error event' do
        e = nil

        begin
          raise StandardError, 'Something went wrong'
        rescue StandardError => exception # rubocop:disable Naming/RescuedExceptionsVariableName
          e = exception
        end

        expect(events).to receive(:log_event).with(
          'event.type' => 'error',
          'error.message' => 'Crawl failure: StandardError: Something went wrong',
          'error.stack_trace' => kind_of(String)
        )

        events.log_error(e, 'Crawl failure')
      end
    end

    context 'without backtrace' do
      it 'should generate an error event' do
        e = StandardError.new('Something went wrong')

        expect(events).to receive(:log_event).with(
          'event.type' => 'error',
          'error.message' => 'Crawl failure: StandardError: Something went wrong',
          'error.stack_trace' => nil
        )

        events.log_error(e, 'Crawl failure')
      end
    end
  end

  describe '#url_output' do
    let(:url) { Crawler::Data::URL.parse('http://example.com/') }
    let(:sink_name) { 'app_search' }
    let(:outcome) { 'success' }
    let(:message) { 'Something went wrong' }
    let(:system_logger_io) { StringIO.new }
    let(:expected_message) { "Processed crawl results from the page '#{url}' via the #{sink_name} output. Outcome: #{outcome}. Message: #{message}." }

    before do
      allow(events).to receive(:system_logger).and_return(Logger.new(system_logger_io))
    end

    it 'should write helpful message to system logger' do
      events.url_output(
        :url => url,
        :sink_name => sink_name,
        :outcome => outcome,
        :start_time => Time.now,
        :end_time => Time.now,
        :duration => 0,
        :message => message
      )

      expect(system_logger_io.string).to match(%r{INFO -- : #{Regexp.escape(expected_message)}})
    end

    context 'failure outcome' do
      let(:outcome) { 'failure' }

      it 'should write helpful message to system logger with WARN severity' do
        events.url_output(
          :url => url,
          :sink_name => sink_name,
          :outcome => outcome,
          :start_time => Time.now,
          :end_time => Time.now,
          :duration => 0,
          :message => message
        )

        expect(system_logger_io.string).to match(%r{WARN -- : #{Regexp.escape(expected_message)}})
      end
    end
  end

  describe '#crawl_status' do
    let(:crawl_status) do
      {
        :queue_size => 1,
        :pages_visited => 2,
        :urls_seen => 3,
        :crawl_duration_msec => 3.123,
        :crawling_time_msec => 2.123,
        :avg_response_time_msec => 1.001,
        :active_threads => 4,
        :http_client => {
          :max_connections => 10,
          :used_connections => 1
        },
        :status_codes => {
          '200' => 1,
          '500' => 2
        }
      }
    end

    let(:crawl) { double(:crawl, :status => crawl_status) }

    it 'should emit a crawl-status event' do
      expect(config).to receive(:output_event).with(
        hash_including('event.action' => 'crawl-status')
      )
      events.crawl_status(crawl)
    end

    it 'should log the status into the system log' do
      system_logger = double(:system_logger)
      allow(config).to receive(:system_logger).and_return(system_logger)
      expect(system_logger).to receive(:info).with(
        /Crawl status.*queue_size=#{crawl_status[:queue_size]}/
      )
      events.crawl_status(crawl)
    end

    it 'should properly format the stats to be ECS-compatible' do
      client_status = crawl_status[:http_client]
      http_codes = crawl_status[:status_codes]
      expect(config).to receive(:output_event).with(
        hash_including(
          'crawler.status.queue_size' => crawl_status[:queue_size],
          'crawler.status.crawl_duration_msec' => crawl_status[:crawl_duration_msec],
          'crawler.status.http_client.max_connections' => client_status[:max_connections],
          'crawler.status.status_codes.200' => http_codes['200'],
          'crawler.status.status_codes.500' => http_codes['500']
        )
      )
      events.crawl_status(crawl)
    end
  end
end
