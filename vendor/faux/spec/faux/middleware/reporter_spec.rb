require 'spec_helper'

describe Faux::Middleware::Reporter do
  let(:site) do
    build_rack_test_session(:status)
    Class.new(Faux::Base)
  end

  def app
    site
  end

  it 'reports a count of the routes that have been visited' do
    pending "Intermittent error comes up (probably due to status not being cleared between test runs)"

    site.page '/foo'

    get '/foo'
    get '/foo'
    get '/status'

    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq('/foo' => 2)
  end
end
