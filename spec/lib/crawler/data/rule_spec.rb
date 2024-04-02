# frozen_string_literal: true

RSpec.describe(Crawler::Data::Rule) do
  describe '#url_match?' do
    it 'allows rule' do
      rule = Crawler::Data::Rule.new(:allow, :url_pattern => %r{\Ahttp://example.com/test[0-9]})

      expect(rule.policy).to eq(:allow)
      expect(rule.url_match?(Crawler::Data::URL.parse('http://example.com/test1'))).to eq(true)
      expect(rule.url_match?(Crawler::Data::URL.parse('http://example.com/testx'))).to eq(false)
    end

    it 'denies rule' do
      rule = Crawler::Data::Rule.new(:deny, :url_pattern => %r{\Ahttp://test[0-9].example.com})

      expect(rule.policy).to eq(:deny)
      expect(rule.url_match?(Crawler::Data::URL.parse('http://test1.example.com'))).to eq(true)
      expect(rule.url_match?(Crawler::Data::URL.parse('http://testx.example.com'))).to eq(false)
    end

    it 'should time out on really complex matching rules' do
      regex = /((((((a*)*)*)*)*)*)*((((((a*)*)*)*)*)*)*((((((a*)*)*)*)*)*)*$/
      rule = Crawler::Data::Rule.new(:deny, :url_pattern => regex)
      url = Crawler::Data::URL.parse('http://test1.example.com//aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab')

      expect { rule.url_match?(url) }.to raise_error(Timeout::Error)
    end
  end
end
