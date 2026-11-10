#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Agent::Unit) do
  let(:expected) do
    {
      id: 'input-1', type: :INPUT, state: :HEALTHY, config_state_idx: 1, log_level: :DEBUG,
      config: { id: 'input-1', type: 'crawler', source: { 'domains' => [] } }
    }
  end

  subject(:unit) { described_class.new(expected) }

  it 'starts in the STARTING state' do
    expect(unit.to_observed).to eq(
      id: 'input-1', type: :INPUT, config_state_idx: 1, state: :STARTING, message: '', payload: nil
    )
    expect(unit).to be_input
    expect(unit).not_to be_output
    expect(unit.config_type).to eq('crawler')
    expect(unit.source).to eq('domains' => [])
    expect(unit.key).to eq(['input-1', :INPUT])
  end

  it 'keeps the configuration when an update omits it' do
    unit.update(id: 'input-1', type: :INPUT, state: :STOPPED, config_state_idx: 1, log_level: :INFO)
    expect(unit.config).to eq(expected[:config])
    expect(unit.log_level).to eq(:INFO)
    expect(unit).to be_expected_stopped
  end

  it 'replaces the configuration when an update includes it' do
    unit.update(expected.merge(config_state_idx: 2, config: { type: 'crawler', source: { 'x' => 1 } }))
    expect(unit.config_idx).to eq(2)
    expect(unit.source).to eq('x' => 1)
  end

  it 'tracks the observed state and payload' do
    unit.set_state(:HEALTHY, 'running', payload: { 'crawl' => 'x' })
    expect(unit.to_observed).to include(state: :HEALTHY, message: 'running', payload: { 'crawl' => 'x' })

    unit.set_state(:DEGRADED, 'oops')
    expect(unit.to_observed).to include(state: :DEGRADED, message: 'oops', payload: { 'crawl' => 'x' })
  end
end
