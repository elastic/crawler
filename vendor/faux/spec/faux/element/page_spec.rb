#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'spec_helper'

describe Faux::Element::Page do

  let(:site) { Class.new(Faux::Base) }

  def app
    site
  end

  it 'should return a 200 by default' do
    site.page '/foo'

    get '/foo'
    expect(last_response.status).to eq(200)
  end

  it 'should return the specified response' do
    app.page '/not_found' do
      status 404
    end

    get '/not_found'
    expect(last_response.status).to eq(404)
  end

  it 'includes links in the response body' do
    app.page '/foo' do
      body do
        link_to '/cool_beans'
      end
    end

    get '/foo'
    expect(last_response.body).to match '<a href=\"/cool_beans\">'
  end

  it 'supports creating absolute links' do
    app.page '/foo' do
      body do
        link_to '/cool_beans', :relative => false
      end
    end

    get '/foo'
    expect(last_response.body).to match 'http://example.org/cool_beans'
  end

  it 'should accept custom headers' do
    app.page '/foo' do
      headers "Content-Type" => 'text/plain'
    end

    get '/foo'
    expect(last_response.header['Content-Type']).to match 'text/plain'
  end

  it 'returns correct content-type' do
    app.page '/foo' do
      link_to '/cool_beans'
    end

    get '/foo'
    expect(last_response.content_type).to eq 'text/html'
  end

  context 'supports redirection' do
    it 'with a 302 default' do
      app.page '/foo' do
        redirect '/bar'
      end

      get '/foo'
      expect(last_response.status).to eq(302)
      expect(last_response.header['Location']).to eq('http://example.org/bar')
    end

    it 'with a 301 option' do
      app.page '/foo' do
        redirect '/bar', :permanent => true
      end

      get '/foo'
      expect(last_response.status).to eq(301)
      expect(last_response.header['Location']).to eq('http://example.org/bar')
    end

    it 'with relative redirect url' do
      app.page '/foo' do
        redirect '/bar'
      end

      get '/foo'
      expect(last_response.header['Location']).to eq('http://example.org/bar')
    end

    it 'with absolute redirect url' do
      app.page '/foo' do
        redirect '/bar', :relative => true
      end

      get '/foo'
      expect(last_response.header['Location']).to eq('/bar')
    end
  end

  it 'supports adding a canonical link' do
    app.page '/foo' do
      head do
        canonical_to '/bar'
      end
    end

    get '/foo'
    expect(last_response.body).to match 'rel="canonical" href="/bar"'
  end

  it 'supports adding a robots meta tag' do
    app.page '/foo' do
      head do
        robots 'noindex'
      end
    end

    get '/foo'
    expect(last_response.body).to match '<meta name="robots" content="noindex">'
  end

  it 'supports adding a link to atom feed' do
    app.page '/foo' do
      head do
        atom_to '/atom.xml'
      end
    end

    get '/foo'
    expect(last_response.body).to match '<link rel="alternate" type="application/atom\+xml" href="/atom.xml" />'
  end

  it 'supports adding a base tag' do
    app.page '/foo' do
      head do
        base '/page/page.html'
      end
    end

    get '/foo'
    expect(last_response.body).to match '<base href="/page/page.html">'
  end

  it 'sets head and body content' do
    app.page '/foobar' do
      head do
        base '/page/page.html'
      end
      body do
        link_to '/bang'
      end
    end

    get '/foobar'
    expect(last_response.body).to match '<head><base href="/page/page.html"></head>'
    expect(last_response.body).to match '<body><a href=\"/bang\">/bang</a></body>'
  end

  describe '#text' do
    it 'supports adding text to the body' do
      app.page '/bar' do
        body do
          text do
            'Hello, world!'
          end
        end
      end

      get '/bar'
      expect(last_response.body).to match('<body>Hello, world!</body>')
    end

    it 'supports adding text to the body with other blocks' do
      app.page '/bar' do
        body do
          text { 'Hello, world!' }
          link_to 'foo'
          text { 'Goodbye, world!' }
        end
      end

      get '/bar'
      expect(last_response.body).to match(%Q(Hello, world!\n<a href="foo">foo</a>\nGoodbye, world!))
    end
  end
end
