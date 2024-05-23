#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'spec_helper'

describe Faux::Site do
  let(:site) { Faux.site }

  it 'starts a Webrick handler for Rack' do
    server = double("server")
    expect(::Rack::Server).to receive(:new).with(:Port => 9393, :app => site, :server => :webrick).and_return(server)
    expect(server).to receive(:start)

    faux = Faux::Site.new(site, {})
    sleep(1)
  end
end
