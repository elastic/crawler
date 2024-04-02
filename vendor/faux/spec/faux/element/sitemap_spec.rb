require 'spec_helper'

describe Faux::Element::Sitemap do
  let(:site) { Class.new(Faux::Base) }

  def app
    site
  end

  it 'should return 200 by default for sitemap' do
    site.sitemap '/sitemap.xml'

    get '/sitemap.xml'
    expect(last_response.status).to eq 200
  end

  it 'should return xml' do
    site.sitemap '/sitemap.xml'

    get '/sitemap.xml'
    expect(last_response.content_type).to eq 'application/xml'
  end

  context 'sitemap of URLs' do
    it 'includes links into generated sitemap' do
      site.sitemap '/sitemap.xml' do
        link_to '/anothersite'
      end

      get '/sitemap.xml'
      expect(last_response.body).to match 'http://example.org/anothersite'
    end

    it 'supports creating relative links' do
      site.sitemap '/sitemap.xml' do
        link_to '/anothersite', :relative => true
      end

      get '/sitemap.xml'
      expect(last_response.body).to match '<loc>/anothersite</loc>'
    end
  end

  context 'sitemap index' do
    it 'defines an index' do
      site.sitemap_index '/sitemap.xml'

      get '/sitemap.xml'
      expect(last_response.body).to match 'sitemapindex'
    end

    it 'supports creating links' do
      site.sitemap_index '/sitemap.xml' do
        link_to '/sitemap_2.xml'
      end

      get '/sitemap.xml'
      expect(last_response.body).to match '<loc>http://example.org/sitemap_2.xml</loc>'
    end
  end
end
