#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'openssl'

RSpec.describe(Crawler::Agent::Connection) do
  def self_signed_pair # rubocop:disable Metrics/AbcSize
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/CN=localhost')
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after = cert.not_before + 3600
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    [cert.to_pem, key.to_pem]
  end

  let(:base) { { addr: '127.0.0.1:6789', server_name: 'localhost', token: 't', services: [:CheckinV2] } }

  it 'rejects unix socket addresses' do
    info = Crawler::Agent::StartupInfo.new(base.merge(addr: 'unix:///tmp/agent.sock'))
    expect { described_class.channel(info) }.to raise_error(Crawler::Agent::Error, /only TCP addresses/)
  end

  it 'builds a mutual TLS channel from the PEM material provided by Agent' do
    cert, key = self_signed_pair
    info = Crawler::Agent::StartupInfo.new(base.merge(ca_cert: cert, peer_cert: cert, peer_key: key,
                                                      max_message_size: 4096))
    channel = described_class.channel(info)
    expect(channel.authority).to eq('localhost')
    channel.shutdownNow
  end

  it 'sends the server name as SNI even without a dot in it' do
    cert, key = self_signed_pair
    info = Crawler::Agent::StartupInfo.new(
      base.merge(server_name: 'crawler-default', ca_cert: cert, peer_cert: cert, peer_key: key)
    )
    engine = described_class.ssl_context(info).newEngine(
      Java::IoGrpcNettyShadedIoNettyBuffer::ByteBufAllocator::DEFAULT, 'crawler-default', 6789
    )
    expect(engine.getSSLParameters.getServerNames.map(&:getAsciiName)).to eq(['crawler-default'])
  end

  it 'builds an insecure channel when no certificates are provided' do
    channel = described_class.channel(Crawler::Agent::StartupInfo.new(base))
    expect(channel.authority).to eq('localhost')
    channel.shutdownNow
  end
end
