#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'spec_helper'

describe Faux::Element::PathWithContentLength do
  let(:site) { Class.new(Faux::Base) }

  def app
    site
  end

  it 'should return valid page' do
    site.path_with_content_length '/large_page'

    get '/large_page'
    expect(last_response.content_type).to eq 'text/html'
  end

  it 'should return page of specified size' do
    site.path_with_content_length '/large_page', 10.megabytes

    get '/large_page'
    expect(last_response.content_length).to eq 10.megabytes
  end
end
