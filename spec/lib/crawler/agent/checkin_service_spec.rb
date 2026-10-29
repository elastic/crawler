#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Agent::CheckinService) do
  let(:agent) { RSpec::Support::FakeAgent.new }
  let(:channel) { agent.channel }
  let(:version_info) { { name: 'crawler', meta: { 'input' => 'crawler' } } }
  let(:client) { Crawler::Agent::Client.new(agent.startup_info, version_info:) }
  let(:handler) { instance_double(Crawler::Agent::CrawlHandler) }
  let(:logger) { instance_double(Crawler::Logging::CrawlLogger, info: nil, warn: nil, error: nil, debug: nil) }
  let(:unit) { { id: 'in', type: :INPUT, state: :HEALTHY, config_state_idx: 4, config: { type: 'crawler' } } }

  subject(:service) { described_class.new(client, channel, handler, logger:, interval: 60) }

  let!(:thread) { Thread.new { service.run } }

  after do
    service.stop
    begin
      thread.join(5)
    rescue Crawler::Agent::Error
      nil
    end
    channel.shutdownNow
    agent.stop
  end

  it 'checks in immediately with the version info and no units' do
    expect(agent.next_observed).to include(token: 'token', units: [], version_info: version_info.merge(build_hash: ''))
  end

  it 'applies expected units through the handler and reports them back' do
    agent.next_observed
    expect(handler).to receive(:apply).with(client) do |c|
      c.units.first.set_state(:HEALTHY, 'configured')
    end
    agent.send_expected(units: [unit], component_idx: 1)

    observed = agent.next_observed
    expect(observed[:version_info]).to be_nil
    expect(observed[:component_idx]).to eq(1)
    expect(observed[:units]).to eq([{ id: 'in', type: :INPUT, config_state_idx: 4, state: :HEALTHY,
                                      message: 'configured', payload: nil }])
  end

  it 'keeps checking in when the handler fails' do
    agent.next_observed
    allow(handler).to receive(:apply).and_raise(RuntimeError, 'boom')
    expect(logger).to receive(:error).with(/Failed to apply the expected configuration: RuntimeError: boom/)
    agent.send_expected(units: [unit], component_idx: 1)
    expect(agent.next_observed[:units].first).to include(id: 'in', state: :STARTING)
  end

  it 'does not call the handler when nothing changed' do
    agent.next_observed
    expect(handler).to receive(:apply).once
    agent.send_expected(units: [unit], component_idx: 1)
    agent.next_observed
    agent.send_expected(units: [unit.except(:config)], component_idx: 1)
    agent.next_observed
  end

  it 'checks in on request' do
    agent.next_observed
    service.request_checkin
    expect(agent.next_observed(timeout: 2)).to include(token: 'token')
  end

  it 'fails when Agent goes away' do
    agent.next_observed
    agent.stop
    expect { thread.join(5) }.to raise_error(Crawler::Agent::Error, /checkin stream failed/)
  end
end
