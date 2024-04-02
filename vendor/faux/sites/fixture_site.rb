class FixtureSite < Faux::Base
  fixture '/' do
    path 'spec/fixtures/simple.html'
  end

  fixture '/foo' do
    headers 'Content-Type' => 'application/xml'
    path 'spec/fixtures/atom-feed-example-com.xml'
  end
end
