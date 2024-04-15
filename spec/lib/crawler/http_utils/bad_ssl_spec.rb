# frozen_string_literal: true

#
# Since these specs run against an external 3rd party service, we don't want to
# run them by default, potentially introducing flakiness into our CI jobs.
#
skip = ENV['BAD_SSL'] ? false : 'Set BAD_SSL=1 to run SSL tests!'

RSpec.describe(Crawler::HttpUtils, 'vs bad SSL:', skip: skip) do
  let(:client_config) do
    {
      loopback_allowed: false,
      private_networks_allowed: false,
      logger: Logger.new($stdout)
    }
  end
  let(:client) { Crawler::HttpClient.new(client_config) }

  def get
    client.get(Crawler::Data::URL.parse(url))
  end

  let(:error) do
    res = begin get; rescue StandardError => e; e; end
    expect(res).to be_a(Crawler::HttpUtils::SslException)
    res
  end

  #-----------------------------------------------------------------------------
  context 'expired SSL certificate' do
    let(:url) { 'https://expired.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL certificate expired/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'SSL certificate with an incorrect host' do
    let(:url) { 'https://wrong.host.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL host name issue/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'Self-signed SSL certificate' do
    let(:url) { 'https://self-signed.host.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL certificate chain is invalid/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'SSL cert with an untrusted root' do
    let(:url) { 'https://untrusted-root.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL certificate chain is invalid/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'SSL response with an incomplete chain' do
    let(:url) { 'https://incomplete-chain.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL certificate chain is invalid/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'SSL response with a reversed chain' do
    let(:url) { 'https://reversed-chain.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL certificate chain is invalid/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'Revoked SSL certificate', skip: 'We do not support CRL or OCSP yet' do
    let(:url) { 'https://revoked.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/Revoked/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'SSL servers with DH480 only' do
    let(:url) { 'https://dh480.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL handshake error/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'SSL servers with DH512 only' do
    let(:url) { 'https://dh512.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL handshake error/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'SSL servers with DH1024 only', pending: 'DH1024 is still supported by our Java' do
    let(:url) { 'https://dh1024.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL handshake error/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'SSL servers with DH2048 only', pending: 'DH2048 is still supported by our Java' do
    let(:url) { 'https://dh2048.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL handshake error/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'TLS/1.0' do
    let(:url) { 'https://tls-v1-0.badssl.com:1010/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL handshake error.*TLS10/)
    end
  end

  #-----------------------------------------------------------------------------
  context 'TLS/1.1' do
    let(:url) { 'https://tls-v1-1.badssl.com:1011/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL handshake error.*TLS11/)
    end
  end

  #-----------------------------------------------------------------------------
  context '3DES cipher' do
    let(:url) { 'https://3des.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL handshake error/)
    end
  end

  #-----------------------------------------------------------------------------
  context '3DES cipher' do
    let(:url) { 'https://3des.badssl.com/' }

    it 'should provide a nice specific message' do
      expect(error.message).to match(/SSL handshake error/)
    end
  end
end
