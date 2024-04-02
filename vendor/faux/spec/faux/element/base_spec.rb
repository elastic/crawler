require 'spec_helper'

describe Faux::Element::Base do
  before :each do
    allow_any_instance_of(Faux::Element::Base).to receive(:response_body).and_return('body')
  end

  it 'should set defaults' do
    base = Faux::Element::Base.new({})
    expect(base.call(double)).to eq [200, {'Content-Type' => 'text/html'}, 'body']
  end

  it 'sets status' do
    content = Proc.new { status 400 }
    base = Faux::Element::Base.new({}, &content)
    expect(base.call(double)).to eq [400, {'Content-Type' => 'text/html'}, 'body']
  end

  it 'sets headers' do
    content = Proc.new { headers 'Content-Type' => 'text/plain' }
    base = Faux::Element::Base.new({}, &content)
    expect(base.call(double)).to eq [200, {'Content-Type' => 'text/plain'}, 'body']
  end
end
