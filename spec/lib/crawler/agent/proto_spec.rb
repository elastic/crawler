#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Agent::Proto) do
  describe '.build / .to_h' do
    it 'round-trips scalars, enums, bytes and repeated fields' do
      message = described_class.build(
        :ActionRequest,
        id: 'action-1', name: 'crawl', params: '{"a":1}', unit_id: 'u1', unit_type: :OUTPUT, type: 'custom', level: 2
      )

      expect(described_class.to_h(message)).to eq(
        id: 'action-1', name: 'crawl', params: '{"a":1}', unit_id: 'u1', unit_type: :OUTPUT, type: :CUSTOM, level: :UNIT
      )
    end

    it 'round-trips nested messages, maps and structs' do
      payload = {
        'crawl' => { 'id' => 'x', 'pages' => 10, 'ratio' => 0.5, 'done' => true, 'err' => nil, 'tags' => %w[a b] }
      }
      message = described_class.build(
        :CheckinObserved,
        token: 'tok',
        version_info: { name: 'crawler', meta: { 'input' => 'crawler' }, build_hash: 'abc' },
        units: [{ id: 'unit-1', type: :INPUT, config_state_idx: 3, state: :HEALTHY, message: 'ok', payload: }],
        component_idx: 2,
        pid: 1234
      )

      result = described_class.to_h(message)
      expect(result[:token]).to eq('tok')
      expect(result[:version_info]).to eq(name: 'crawler', meta: { 'input' => 'crawler' }, build_hash: 'abc')
      expect(result[:component_idx]).to eq(2)
      expect(result[:pid]).to eq(1234)
      expect(result[:units_timestamp]).to be_nil
      expect(result[:units]).to eq(
        [{ id: 'unit-1', type: :INPUT, config_state_idx: 3, state: :HEALTHY, message: 'ok', payload: }]
      )
    end

    it 'round-trips timestamps' do
      time = Time.at(1_700_000_000, 123_456_789, :nsec)
      message = described_class.build(:CheckinExpected, units_timestamp: time)
      expect(described_class.to_h(message)[:units_timestamp]).to eq(time)
    end

    it 'keeps binary bytes intact' do
      bytes = (0..255).map(&:chr).join.b
      message = described_class.build(:StartUpInfo, ca_cert: bytes)
      expect(described_class.to_h(message)[:ca_cert]).to eq(bytes)
    end

    it 'skips nil attributes' do
      message = described_class.build(:ActionResponse, id: 'x', result: nil)
      expect(described_class.to_h(message)[:result]).to eq('')
    end

    it 'raises on unknown fields' do
      expect { described_class.build(:ActionResponse, nope: 1) }.to raise_error(ArgumentError, /Unknown field nope/)
    end

    it 'raises on unknown enum values' do
      expect do
        described_class.build(:UnitObserved, state: :bogus)
      end.to raise_error(ArgumentError, /Unknown value :bogus/)
    end

    it 'raises on unknown message types' do
      expect { described_class.build(:Nope) }.to raise_error(ArgumentError, /Unknown message type/)
    end
  end

  describe '.encode / .decode' do
    it 'converts structs and timestamps parsed from the wire' do
      time = Time.at(1_700_000_000, 5, :nsec)
      message = described_class.build(
        :CheckinExpected,
        units_timestamp: time,
        units: [
          { id: 'u', config: { source: { 'domains' => [{ 'url' => 'https://a' }], 'depth' => 2, 'on' => true } } }
        ]
      )
      decoded = described_class.to_h(described_class.decode(:CheckinExpected, described_class.encode(message)))
      expect(decoded[:units_timestamp]).to eq(time)
      expect(decoded[:units].first[:config][:source]).to eq(
        'domains' => [{ 'url' => 'https://a' }], 'depth' => 2, 'on' => true
      )
    end

    it 'serializes messages to and from binary' do
      message = described_class.build(:StartUpInfo, addr: '127.0.0.1:6789', token: 't', services: %i[CheckinV2 Log])
      decoded = described_class.decode(:StartUpInfo, described_class.encode(message))
      expect(described_class.to_h(decoded)).to include(addr: '127.0.0.1:6789', token: 't', services: %i[CheckinV2 Log])
    end
  end

  describe '.rpc' do
    it 'describes the bidirectional streaming methods of the ElasticAgent service' do
      checkin = described_class.rpc('CheckinV2')
      expect(checkin.getFullMethodName).to eq('proto.ElasticAgent/CheckinV2')
      expect(checkin.getType.name).to eq('BIDI_STREAMING')
      expect(described_class.rpc('Actions').getFullMethodName).to eq('proto.ElasticAgent/Actions')
    end

    it 'raises on unknown methods' do
      expect { described_class.rpc('Nope') }.to raise_error(ArgumentError, /Unknown rpc/)
    end
  end
end
