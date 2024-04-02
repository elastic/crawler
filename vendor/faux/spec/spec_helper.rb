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
