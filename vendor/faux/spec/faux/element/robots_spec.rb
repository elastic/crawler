require 'spec_helper'

describe Faux::Element::Robots do
  let(:site) { Class.new(Faux::Base) }

  def app
    site
  end

  it 'should be accessible on \robots.txt' do
    site.robots

    get '/robots.txt'
    expect(last_response).to_not be_empty
  end

  it 'should render names' do
    site.robots do
      disallow '/blocked'
    end

    get '/robots.txt'
    expect(last_response.body).to eq "Disallow: /blocked\n"
  end

  it 'should render names with dashes / underscores' do
    site.robots do
      user_agent '*'
    end

    get '/robots.txt'
    expect(last_response.body).to eq "User-agent: *\n"
  end

  it 'combines multiple declarations on one file' do
    site.robots do
      disallow '/blocked'
      sitemap 'http://example.com/sitemap.xml'
    end

    get '/robots.txt'
    expect(last_response.body).to eq "Disallow: /blocked\nSitemap: http://example.com/sitemap.xml\n"
  end

  it 'returns correct content-type' do
    site.robots do
      disallow '/blocked'
      sitemap 'http://example.com/sitemap.xml'
    end

    get '/robots.txt'
    expect(last_response.content_type).to eq "text/plain"
  end

  it 'supports converting relative sitemap paths to absolute paths' do
    site.robots do
      sitemap '/sitemap.xml', :relative => true
    end

    get '/robots.txt'
    expect(last_response.body).to match 'http://example.org/sitemap.xml'
  end
end
