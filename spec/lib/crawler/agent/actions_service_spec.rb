#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'json'

RSpec.describe(Crawler::Agent::ActionsService) do
  let(:agent) { RSpec::Support::FakeAgent.new }
  let(:channel) { agent.channel }
  let(:client) { Crawler::Agent::Client.new(agent.startup_info, version_info: { name: 'crawler' }) }
  let(:handler) { instance_double(Crawler::Agent::CrawlHandler) }
  let(:logger) { instance_double(Crawler::Logging::CrawlLogger, info: nil, warn: nil, error: nil, debug: nil) }

  subject(:service) { described_class.new(client, channel, handler, logger:) }

  let!(:thread) { Thread.new { service.run } }

  after do
    service.stop
    thread.join(5)
    channel.shutdownNow
    agent.stop
  end

  def response
    agent.next_action_response.tap { |r| r[:result] = JSON.parse(r[:result]) }
  end

  it 'announces itself with an init response' do
    expect(response).to include(token: 'token', id: 'init', status: :SUCCESS, result: {})
  end

  it 'dispatches actions to the handler and returns the result' do
    response
    expect(handler).to receive(:handle_action).with(hash_including(id: 'a1', name: 'crawl',
                                                                   params: { 'force' => true }))
                                              .and_return(crawl_id: 'x')
    agent.send_action(id: 'a1', name: 'crawl', params: '{"force":true}')
    expect(response).to include(id: 'a1', status: :SUCCESS, result: { 'crawl_id' => 'x' })
  end

  it 'reports rejected actions as failed with the rejection message' do
    response
    allow(handler).to receive(:handle_action).and_raise(Crawler::Agent::ActionError, 'busy')
    agent.send_action(id: 'a2', name: 'crawl')
    expect(response).to include(id: 'a2', status: :FAILED, result: { 'error' => 'busy' })
  end

  it 'reports unexpected handler errors as failed' do
    response
    allow(handler).to receive(:handle_action).and_raise(RuntimeError, 'boom')
    agent.send_action(id: 'a3', name: 'crawl')
    expect(response).to include(id: 'a3', status: :FAILED, result: { 'error' => 'Action failed: boom' })
  end

  it 'rejects diagnostics actions' do
    response
    agent.send_action(id: 'd1', type: :DIAGNOSTICS)
    expect(response).to include(id: 'd1', status: :FAILED,
                                result: { 'error' => 'Diagnostics actions are not supported' })
  end

  it 'rejects actions with invalid params' do
    response
    agent.send_action(id: 'a4', name: 'crawl', params: 'not json')
    expect(response).to include(id: 'a4', status: :FAILED, result: { 'error' => /not valid JSON/ })
    agent.send_action(id: 'a5', name: 'crawl', params: '[1]')
    expect(response).to include(id: 'a5', status: :FAILED, result: { 'error' => 'Action params must be a JSON object' })
  end

  it 'finishes when Agent completes the stream' do
    response
    agent.complete(RSpec::Support::FakeAgent::ACTIONS)
    expect(thread.join(5)).not_to be_nil
  end
end
