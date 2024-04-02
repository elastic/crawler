# frozen_string_literal: true

RSpec.describe Crawler::Data::URL do
  def url(s)
    Crawler::Data::URL.parse(s)
  end

  describe '#normalized_url' do
    it 'should remove the url fragment from the URL' do
      expect(url('https://google.com/something#some-fragment').normalized_url.fragment).to be_nil
    end
  end

  describe '#domain' do
    it 'should return a domain object for the given URL' do
      domain = url('https://google.com').domain
      expect(domain).to be_a(Crawler::Data::Domain)
      expect(domain.to_s).to eq('https://google.com:443')
    end
  end

  describe '#domain_name' do
    it 'returns a domain name for a given URL' do
      expect(url('https://google.com/').domain_name).to eq('https://google.com')
    end

    it 'includes a port if a port is non-standard' do
      expect(url('https://google.com:1234/').domain_name).to eq('https://google.com:1234')
    end

    it 'strips away the path, URL params and the URL fragment' do
      expect(url('https://google.com/hello?yo=42#boom').domain_name).to eq('https://google.com')
    end
  end

  describe '#extract_by_regexp' do
    let(:url) { 'https://google.com/hello?yo=42#boom' }
    let(:regexp) { nil }
    let(:parsed_url) { Crawler::Data::URL.parse(url) }
    subject { parsed_url.extract_by_regexp(regexp) }

    context 'when regexp is not a regexp type' do
      let(:regexp) { 123 }
      it 'raises an argument error' do
        expect { parsed_url.extract_by_regexp(regexp) }.to raise_error(ArgumentError)
      end
    end

    context 'when regex group are used' do
      let(:regexp) { /\?([a-z]{2})=([0-9]+)/ }

      it { is_expected.to be_kind_of(Array) }
      it { is_expected.to contain_exactly('yo', '42') }
    end

    context 'when regex group are not used' do
      let(:regexp) { /\?[a-z]{2}=[0-9]+/ }

      it { is_expected.to be_kind_of(Array) }
      it { is_expected.to contain_exactly('?yo=42') }
    end

    context 'when regexp does not match' do
      let(:regexp) { /somthingthatdoesnotmatch/ }

      it { is_expected.to be_kind_of(Array) }
      it { is_expected.to be_empty }
    end
  end
end
