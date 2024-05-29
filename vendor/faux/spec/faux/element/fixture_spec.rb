#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'spec_helper'

describe Faux::Element::Fixture do
  let(:site) { Class.new(Faux::Base) }

  def app
    site
  end

  it 'accepts path as argument' do
    app.fixture '/foo' do
      path 'spec/fixtures/simple.html'
    end

    get '/foo'
    expect(last_response.body).to match '<title>example</title>'
    expect(last_response.body).to match '<a href="another">another link</a>'
  end

  it 'allows headers and status to be specified' do
    app.fixture '/foo' do
      status 404
      headers "Content-Type" => 'text/plain'
      path 'spec/fixtures/simple.html'
    end

    get '/foo'
    expect(last_response.body).to match '<title>example</title>'
    expect(last_response.header['Content-Type']).to match 'text/plain'
    expect(last_response.status).to eq(404)
  end

  it 'works with xml files' do
    app.fixture '/foo' do
      headers 'Content-Type' => 'application/xml'
      path 'spec/fixtures/atom-feed-example-com.xml'
    end

    get '/foo'
    expect(last_response.body).to match '<feed xmlns="http://www.w3.org/2005/Atom">'
  end

  it 'raises error if path is wrong' do
    app.fixture '/foo' do
      path 'doesnt-exist'
    end

    expect do
      get '/foo'
    end.to raise_error ArgumentError
  end
end
