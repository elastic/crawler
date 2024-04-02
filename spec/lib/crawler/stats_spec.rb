# frozen_string_literal: true

RSpec.describe(Crawler::Stats) do
  let(:stats) { Crawler::Stats.new }

  #-------------------------------------------------------------------------------------------------
  describe '#crawl_duration_msec' do
    it 'should return nil when crawl has not been started yet' do
      expect(stats.crawl_duration_msec).to be_nil
    end

    it 'should return the time since crawl start while crawl is running' do
      start_time = Time.monotonic_now
      allow(stats).to receive(:crawl_started_at).and_return(start_time)
      sleep(0.5)
      expect(stats.crawl_duration_msec).to be_between(500, (Time.monotonic_now - start_time) * 1000)
    end

    it 'should return the crawl duration after a crawl finish' do
      allow(stats).to receive(:crawl_started_at).and_return(2.minutes.ago.to_f)
      allow(stats).to receive(:crawl_finished_at).and_return(1.minute.ago.to_f)
      expect(stats.crawl_duration_msec).to be_between(60_000, 61_000) # milliseconds
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#update_from_event' do
    it 'should ignore events with an unknown type' do
      expect { stats.update_from_event('event.action' => 'something') }.to_not raise_error
    end

    it 'should register crawl-start events' do
      expect { stats.update_from_event('event.action' => 'crawl-start') }.to change {
        stats.crawl_started_at
      }.from(nil).to(kind_of(Numeric))
    end

    it 'should register crawl-end events' do
      expect { stats.update_from_event('event.action' => 'crawl-end') }.to change {
        stats.crawl_finished_at
      }.from(nil).to(kind_of(Numeric))
    end

    context 'for url-discover events' do
      let(:event) { { 'event.action' => 'url-discover' } }

      context 'with type=denied' do
        let(:event) do
          super().merge(
            'event.type' => :denied,
            'crawler.url.deny_reason' => :already_seen
          )
        end

        it 'should increment the number of denied urls with a given reason' do
          stats.update_from_event(event) # initialize the response codes count
          expect { stats.update_from_event(event) }.to change {
            stats.urls_denied_counts[:already_seen]
          }.by(1)
        end
      end

      context 'with type=allowed' do
        let(:event) { super().merge('event.type' => :allowed) }

        it 'should increment the number of discovered urls' do
          expect { stats.update_from_event(event) }.to change {
            stats.urls_allowed_count
          }.by(1)
        end
      end
    end

    context 'for url-fetch events' do
      let(:duration_msec) { 1234 }
      let(:event) do
        {
          'event.action' => 'url-fetch',
          'event.duration' => duration_msec * 1_000_000, # nanoseconds
          'http.response.status_code' => '200'
        }
      end

      it 'should increment the number of fetched pages' do
        expect { stats.update_from_event(event) }.to change {
          stats.fetched_pages_count
        }.by(1)
      end

      it 'should count response codes' do
        stats.update_from_event(event) # initialize the response codes count
        expect { stats.update_from_event(event) }.to change {
          stats.status_code_counts['200']
        }.by(1)
      end

      it 'should measure response time as time spent crawling' do
        expect { stats.update_from_event(event) }.to change {
          stats.time_spent_crawling_msec
        }.by(duration_msec)
      end
    end
  end
end
