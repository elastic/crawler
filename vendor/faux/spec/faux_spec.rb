#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'spec_helper'

describe Faux::Base do

  let(:site) { Class.new(Faux::Base) }

  def app
    site
  end

  it 'adds a /status route by default' do
    get '/status'
    expect(last_response.status).to eq(200)
  end

end
