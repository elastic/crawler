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
