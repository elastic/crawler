#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::Domain) do
  def domain(url)
    Crawler::Data::Domain.new(url)
  end

  it 'should include the standard port in the normalized version' do
    expect(domain('http://google.com').to_s).to eq('http://google.com:80')
    expect(domain('https://google.com').to_s).to eq('https://google.com:443')
  end

  it 'should include the custom port in the normalized version' do
    expect(domain('https://google.com:123').to_s).to eq('https://google.com:123')
  end

  it 'should strip out the path' do
    expect(domain('https://google.com/something').to_s).to eq('https://google.com:443')
  end

  it 'should strip out the URL fragment' do
    expect(domain('https://google.com/something#foo').to_s).to eq('https://google.com:443')
  end

  context 'when compared to other objects' do
    it 'should use the normalized version for comparison' do
      expect(domain('https://google.com/something#foo') == 'https://google.com:443').to be(true)
    end
  end

  describe '#robots_txt_url' do
    it 'should return URL with /robots.txt as the path' do
      expect(domain('https://google.com').robots_txt_url.to_s).to eq('https://google.com/robots.txt')
      expect(domain('https://google.com/something#foo').robots_txt_url.to_s).to eq('https://google.com/robots.txt')
      expect(domain('https://google.com/something?q=v').robots_txt_url.to_s).to eq('https://google.com/robots.txt')
      expect(domain('https://google.com:123').robots_txt_url.to_s).to eq('https://google.com:123/robots.txt')
    end
  end
end
