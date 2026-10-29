#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Agent::Client) do
  let(:startup_info) { Crawler::Agent::StartupInfo.new(addr: 'a', token: 'tok', services: [:CheckinV2]) }
  let(:version_info) { { name: 'crawler', meta: { 'input' => 'crawler' } } }
  let(:input) do
    { id: 'in', type: :INPUT, state: :HEALTHY, config_state_idx: 1, log_level: :INFO, config: { type: 'crawler' } }
  end
  let(:output) do
    { id: 'out', type: :OUTPUT, state: :HEALTHY, config_state_idx: 1, log_level: :INFO, config: { type: 'es' } }
  end
  let(:expected) { { units: [input, output], component_idx: 1, features_idx: 0, agent_info: { id: 'agent-1' } } }

  subject(:client) { described_class.new(startup_info, version_info:) }

  describe '#apply_expected' do
    it 'creates units and stores agent info on the first check-in' do
      expect(client.apply_expected(expected)).to be(true)
      expect(client.units.map(&:id)).to eq(%w[in out])
      expect(client.inputs.map(&:id)).to eq(%w[in])
      expect(client.outputs.map(&:id)).to eq(%w[out])
      expect(client.agent_info).to eq(id: 'agent-1')
      expect(client.component_idx).to eq(1)
    end

    it 'detects when nothing changed' do
      client.apply_expected(expected)
      expect(client.apply_expected(expected.merge(agent_info: nil))).to be(false)
    end

    it 'updates existing units in place when their config changes' do
      client.apply_expected(expected)
      unit = client.units.first
      unit.set_state(:HEALTHY, 'ok')

      changed = expected.merge(units: [
                                 input.merge(config_state_idx: 2,
                                             config: { type: 'crawler',
                                                       source: { 'x' => 1 } }), output
                               ])
      expect(client.apply_expected(changed)).to be(true)
      expect(client.units.first).to equal(unit)
      expect(unit.config_idx).to eq(2)
      expect(unit.source).to eq('x' => 1)
      expect(unit.state).to eq(:HEALTHY)
    end

    it 'detects expected state changes' do
      client.apply_expected(expected)
      expect(client.apply_expected(expected.merge(units: [input.merge(state: :STOPPED), output]))).to be(true)
      expect(client.units.first).to be_expected_stopped
    end

    it 'detects log level changes and component index changes' do
      client.apply_expected(expected)
      expect(client.apply_expected(expected.merge(units: [input.merge(log_level: :DEBUG), output]))).to be(true)
      expect(client.apply_expected(expected.merge(units: [input.merge(log_level: :DEBUG), output],
                                                  component_idx: 2))).to be(true)
      expect(client.component_idx).to eq(2)
    end

    it 'removes units that are no longer expected' do
      client.apply_expected(expected)
      expect(client.apply_expected(expected.merge(units: [output]))).to be(true)
      expect(client.units.map(&:id)).to eq(%w[out])
    end
  end

  describe '#observed' do
    it 'reports the token, units and version info once' do
      client.apply_expected(expected)
      client.units.first.set_state(:HEALTHY, 'ready')

      first = client.observed
      expect(first).to include(token: 'tok', component_idx: 1, features_idx: 0, supports: [], pid: Process.pid,
                               version_info:)
      expect(first[:units]).to eq(
        [
          { id: 'in', type: :INPUT, config_state_idx: 1, state: :HEALTHY, message: 'ready', payload: nil },
          { id: 'out', type: :OUTPUT, config_state_idx: 1, state: :STARTING, message: '', payload: nil }
        ]
      )
      expect(client.observed).not_to have_key(:version_info)
    end
  end
end
