#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'stringio'

RSpec.describe(Crawler::Agent::StartupInfo) do
  let(:attributes) do
    {
      addr: '127.0.0.1:6789', server_name: 'localhost', token: 'tok', ca_cert: 'CA', peer_cert: 'CERT', peer_key: 'KEY',
      services: %i[CheckinV2 Store], supports: [:CheckinChunking], max_message_size: 100,
      agent_info: { id: 'agent-1', version: '9.1.0', snapshot: false, mode: :MANAGED }
    }
  end

  describe '.read' do
    it 'decodes the StartUpInfo message from the given IO' do
      io = StringIO.new(Crawler::Agent::Proto.encode(Crawler::Agent::Proto.build(:StartUpInfo, attributes)))
      info = described_class.read(io)

      expect(info.addr).to eq('127.0.0.1:6789')
      expect(info.server_name).to eq('localhost')
      expect(info.token).to eq('tok')
      expect(info.ca_cert).to eq('CA')
      expect(info.peer_cert).to eq('CERT')
      expect(info.peer_key).to eq('KEY')
      expect(info.services).to eq(%i[CheckinV2 Store])
      expect(info.max_message_size).to eq(100)
      expect(info.agent_id).to eq('agent-1')
      expect(info.agent_version).to eq('9.1.0')
      expect(info).to be_tls
    end

    it 'fails when nothing was received' do
      expect { described_class.read(StringIO.new('')) }.to raise_error(Crawler::Agent::Error, /No startup information/)
    end
  end

  describe '#initialize' do
    it 'requires an address' do
      expect { described_class.new(attributes.merge(addr: '')) }.to raise_error(Crawler::Agent::Error, /gRPC address/)
    end

    it 'requires the CheckinV2 service' do
      expect { described_class.new(attributes.merge(services: [:Checkin])) }
        .to raise_error(Crawler::Agent::Error, /does not offer the CheckinV2 service/)
    end

    it 'is not tls without certificates' do
      info = described_class.new(attributes.merge(ca_cert: nil, peer_cert: nil, peer_key: nil))
      expect(info).not_to be_tls
      expect(info.agent_id).to eq('agent-1')
    end
  end
end
