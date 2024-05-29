#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'bundler/setup'
require 'rspec'
require 'rack/test'
require 'pry'
require 'awesome_print'

require 'faux'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.color = true
  config.order = 'random'
end
