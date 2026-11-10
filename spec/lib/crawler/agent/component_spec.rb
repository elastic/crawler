#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'json'
require 'stringio'

RSpec.describe(Crawler::Agent::Component) do
  let(:agent) { RSpec::Support::FakeAgent.new }
  let(:stdin) { StringIO.new(agent.startup_info_bytes) }
  let(:logger) { instance_double(Crawler::Logging::CrawlLogger, info: nil, warn: nil, error: nil, debug: nil) }
  let(:channels) { [] }
  let(:channel_factory) { ->(info) { agent.channel.tap { |c| channels << [info, c] } } }

  let(:input_source) do
    { 'domains' => [{ 'url' => 'http://example.com' }], 'output_index' => 'search-web', 'log_level' => 'error' }
  end
  let(:output_source) { { 'hosts' => ['http://localhost:9200'], 'username' => 'elastic', 'password' => 'changeme' } }
  let(:units) do
    [
      { id: 'in', type: :INPUT, state: :HEALTHY, config_state_idx: 1,
        config: { type: 'crawler', source: input_source } },
      { id: 'out', type: :OUTPUT, state: :HEALTHY, config_state_idx: 1,
        config: { type: 'elasticsearch', source: output_source } }
    ]
  end

  let(:release) { Queue.new }
  let(:crawl) { instance_double(Crawler::API::Crawl, outcome: :success, outcome_message: 'all good') }

  subject(:component) { described_class.new(stdin:, logger:, checkin_interval: 60, channel_factory:) }

  before do
    allow(Crawler::API::Crawl).to receive(:new).and_return(crawl)
    allow(crawl).to receive(:start!) { release.pop }
    allow(Signal).to receive(:trap)
  end

  after do
    component.stop
    agent.stop
  end

  def observed_states(states)
    observed = agent.observed_until { |o| o[:units].map { |u| u[:state] } == states }
    observed[:units].to_h { |u| [u[:id], u] }
  end

  it 'runs crawls on behalf of Elastic Agent' do
    thread = Thread.new { component.run }

    first = agent.next_observed
    expect(first).to include(token: 'token', units: [])
    expect(first[:version_info]).to include(name: 'crawler',
                                            meta: { 'input' => 'crawler',
                                                    'version' => Crawler.version })
    expect(Signal).to have_received(:trap).with('INT')
    expect(Signal).to have_received(:trap).with('TERM')
    expect(channels.first.first.agent_id).to eq('agent-id')
    expect(agent.next_action_response).to include(id: 'init', status: :SUCCESS)

    agent.send_expected(units:, component_idx: 1, agent_info: { id: 'agent-id', version: '9.9.9' })
    states = observed_states(%i[HEALTHY HEALTHY])
    expect(states['in']).to include(config_state_idx: 1, message: /Crawler configured for 1 domain/)
    expect(states['out']).to include(config_state_idx: 1, message: /Elasticsearch output configured/)

    agent.send_action(id: 'a1', name: 'crawl')
    response = agent.next_action_response
    expect(response).to include(id: 'a1', status: :SUCCESS)
    result = JSON.parse(response[:result])
    expect(result).to include('status' => 'running', 'trigger' => 'action')
    expect(Crawler::API::Crawl).to have_received(:new).with(an_instance_of(Crawler::API::Config))

    running = agent.observed_until { |o| o[:units].first[:payload]&.dig('crawl', 'status') == 'running' }
    expect(running[:units].first[:message]).to eq("Crawl #{result['crawl_id']} running (trigger: action)")

    agent.send_action(id: 'a2', name: 'crawl')
    expect(JSON.parse(agent.next_action_response[:result]))
      .to eq('error' => "A crawl is already in progress (crawl id: #{result['crawl_id']})")

    release << :done
    finished = agent.observed_until { |o| o[:units].first[:payload]&.dig('crawl', 'status') == 'success' }
    expect(finished[:units].first[:payload]['crawl']).to include('message' => 'all good', 'trigger' => 'action')

    agent.send_expected(units: units.map { |u| u.except(:config).merge(state: :STOPPED) }, component_idx: 1)
    stopped = agent.observed_until { |o| o[:units].map { |u| u[:state] } == %i[STOPPED STOPPED] }
    expect(stopped[:units].map { |u| u[:message] }).to eq(%w[Stopped Stopped])

    component.stop('test over')
    expect(thread.join(10)).not_to be_nil
  end

  it 'stops a running crawl on shutdown' do
    thread = Thread.new { component.run }
    agent.next_observed
    agent.send_expected(units:, component_idx: 1)
    observed_states(%i[HEALTHY HEALTHY])
    agent.send_action(id: 'a1', name: 'crawl')
    agent.next_action_response
    agent.next_action_response
    expect(crawl).to receive(:start_shutdown!).with(reason: 'component shutdown') { release << :done }

    component.stop('shutting down')
    expect(thread.join(10)).not_to be_nil
  end

  it 'fails when the connection to Agent is lost' do
    thread = Thread.new { component.run }
    agent.next_observed
    agent.stop
    expect { thread.join(10) }.to raise_error(Crawler::Agent::Error, /stream failed/)
  end

  it 'fails without startup information' do
    component = described_class.new(stdin: StringIO.new(''), logger:, channel_factory:)
    expect { component.run }.to raise_error(Crawler::Agent::Error, /No startup information/)
  end
end
