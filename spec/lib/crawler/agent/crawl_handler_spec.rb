#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Agent::CrawlHandler) do
  let(:logger) { instance_double(Crawler::Logging::CrawlLogger, info: nil, warn: nil, error: nil, debug: nil) }
  let(:runner) { instance_double(Crawler::Agent::CrawlRunner, running?: false, status: nil) }
  let(:checkins) { [] }
  let(:scheduler) { instance_double(Rufus::Scheduler, cron: nil, shutdown: nil) }

  let(:startup_info) { Crawler::Agent::StartupInfo.new(addr: 'a', token: 'tok', services: [:CheckinV2]) }
  let(:client) { Crawler::Agent::Client.new(startup_info, version_info: { name: 'crawler' }) }

  let(:input_source) do
    { 'domains' => [{ 'url' => 'https://example.com' }], 'output_index' => 'search-web', 'log_level' => 'error' }
  end
  let(:output_source) { { 'hosts' => ['https://es:9200'], 'api_key' => 'key' } }

  def expected_unit(id, type, config_type, source, state: :HEALTHY)
    { id:, type:, state:, config_state_idx: 1, log_level: :INFO, config: { type: config_type, source: } }
  end

  let(:input_unit) { expected_unit('in', :INPUT, 'crawler', input_source) }
  let(:output_unit) { expected_unit('out', :OUTPUT, 'elasticsearch', output_source) }

  subject(:handler) { described_class.new(runner, logger:, on_change: -> { checkins << :checkin }) }

  before { allow(Rufus::Scheduler).to receive(:new).and_return(scheduler) }

  def apply(*units)
    client.apply_expected(units:, component_idx: 1)
    handler.apply(client)
    client.units.to_h { |unit| [unit.id, unit.to_observed] }
  end

  describe '#apply' do
    it 'configures the crawler when a crawler input and an elasticsearch output are present' do
      observed = apply(input_unit, output_unit)
      expect(handler).to be_configured
      expect(observed['in']).to include(state: :HEALTHY,
                                        message: 'Crawler configured for 1 domain(s), waiting for crawl actions')
      expect(observed['out']).to include(state: :HEALTHY, message: 'Elasticsearch output configured (https://es:9200)')
      expect(scheduler).not_to have_received(:cron)
    end

    it 'schedules crawls when the input has a schedule' do
      input_source['schedule'] = { 'pattern' => '*/5 * * * *' }
      expect(scheduler).to receive(:cron).with('*/5 * * * *', overlap: false)
      observed = apply(input_unit, output_unit)
      expect(observed['in'][:message]).to include('scheduled with cron pattern "*/5 * * * *"')
    end

    it 'replaces a previous schedule on reconfiguration' do
      input_source['schedule'] = { 'pattern' => '*/5 * * * *' }
      apply(input_unit, output_unit)
      expect(scheduler).to receive(:shutdown).with(:kill)
      apply(
        expected_unit('in', :INPUT, 'crawler',
                      input_source.merge('max_crawl_depth' => 2)).merge(config_state_idx: 2), output_unit
      )
    end

    it 'fails the input unit on invalid crawler configuration' do
      input_source['domains'] = []
      observed = apply(input_unit, output_unit)
      expect(handler).not_to be_configured
      expect(observed['in']).to include(state: :FAILED,
                                        message: /Invalid crawler configuration: Needs at least one domain/)
    end

    it 'fails both units on an invalid elasticsearch output' do
      output_source.delete('hosts')
      observed = apply(input_unit, output_unit)
      expect(observed['out']).to include(state: :FAILED, message: /Invalid Elasticsearch output: .*no hosts/)
      expect(observed['in']).to include(state: :FAILED, message: 'Waiting for a valid Elasticsearch output')
    end

    it 'reports units as stopped when Agent expects them to stop' do
      apply(input_unit, output_unit)
      allow(runner).to receive(:running?).and_return(true)
      expect(runner).to receive(:stop).with(reason: /stopped by Elastic Agent/)
      observed = apply(input_unit.merge(state: :STOPPED), output_unit.merge(state: :STOPPED))
      expect(observed['in']).to include(state: :STOPPED, message: 'Stopped')
      expect(observed['out']).to include(state: :STOPPED, message: 'Stopped')
      expect(handler).not_to be_configured
    end

    it 'waits for an output when only an input is present' do
      observed = apply(input_unit)
      expect(observed['in']).to include(state: :CONFIGURING, message: 'Waiting for an Elasticsearch output')
    end

    it 'waits for an input when only an output is present' do
      observed = apply(output_unit)
      expect(observed['out']).to include(state: :HEALTHY, message: 'Waiting for a crawler input')
    end

    it 'fails unsupported units' do
      observed = apply(input_unit, output_unit, expected_unit('other', :INPUT, 'filestream', {}))
      expect(observed['other']).to include(state: :FAILED, message: 'Unsupported unit type "filestream"')
      expect(observed['in'][:state]).to eq(:HEALTHY)
    end
  end

  describe '#handle_action' do
    it 'rejects crawl actions until configured' do
      expect { handler.handle_action(name: 'crawl', params: {}) }
        .to raise_error(Crawler::Agent::ActionError, /not received a valid configuration/)
    end

    it 'starts a crawl with a fresh configuration' do
      apply(input_unit, output_unit)
      expect(runner).to receive(:start).with(an_instance_of(Crawler::API::Config), trigger: 'action')
                                       .and_return(crawl_id: 'x', status: 'running')
      expect(handler.handle_action(name: 'crawl', params: {})).to eq(crawl_id: 'x', status: 'running')
    end

    it 'reports the status' do
      allow(runner).to receive(:status).and_return(crawl_id: 'x', status: 'success')
      expect(handler.handle_action(name: 'status',
                                   params: {})).to eq(configured: false,
                                                      crawl: {
                                                        crawl_id: 'x', status: 'success'
                                                      })
    end

    it 'stops a running crawl' do
      allow(runner).to receive_messages(running?: true, status: { crawl_id: 'x', status: 'running' })
      expect(runner).to receive(:stop).with(reason: /stop action/)
      expect(handler.handle_action(name: 'stop', params: {})).to eq(status: 'stopping', crawl_id: 'x')
    end

    it 'rejects stop when nothing is running' do
      expect { handler.handle_action(name: 'stop', params: {}) }.to raise_error(Crawler::Agent::ActionError, /No crawl/)
    end

    it 'rejects unknown actions' do
      expect do
        handler.handle_action(name: 'dance',
                              params: {})
      end.to raise_error(Crawler::Agent::ActionError, /Unknown action "dance"/)
    end
  end

  describe '#crawl_status_changed' do
    it 'publishes the crawl status through the input unit and requests a check-in' do
      observed = apply(input_unit, output_unit)
      expect(observed['in'][:payload]).to be_nil

      handler.crawl_status_changed(crawl_id: 'x', status: 'running', trigger: 'schedule')
      unit = client.units.find(&:input?)
      expect(unit.to_observed).to include(state: :HEALTHY, message: 'Crawl x running (trigger: schedule)',
                                          payload: { crawl: { crawl_id: 'x', status: 'running', trigger: 'schedule' } })

      handler.crawl_status_changed(crawl_id: 'x', status: 'failure', message: 'boom')
      expect(unit.to_observed).to include(state: :DEGRADED, message: 'Crawl x finished with outcome failure: boom')
      expect(checkins).to eq(%i[checkin checkin])
    end

    it 'does nothing when not configured' do
      handler.crawl_status_changed(crawl_id: 'x', status: 'running')
      expect(checkins).to be_empty
    end
  end

  describe '#stop' do
    it 'stops the schedule and waits for a running crawl' do
      input_source['schedule'] = { 'pattern' => '* * * * *' }
      apply(input_unit, output_unit)
      allow(runner).to receive(:running?).and_return(true)
      expect(scheduler).to receive(:shutdown).with(:kill)
      expect(runner).to receive(:stop).with(reason: 'component shutdown')
      expect(runner).to receive(:wait).with(3)
      handler.stop(timeout: 3)
    end
  end
end
