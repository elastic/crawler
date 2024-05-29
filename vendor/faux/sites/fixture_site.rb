#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#
class FixtureSite < Faux::Base
  fixture '/' do
    path 'spec/fixtures/simple.html'
  end

  fixture '/foo' do
    headers 'Content-Type' => 'application/xml'
    path 'spec/fixtures/atom-feed-example-com.xml'
  end
end
