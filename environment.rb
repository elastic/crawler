# frozen_string_literal: true

# Add the lib directory to the load path
$LOAD_PATH << "#{__dir__}/lib"

# Calculate the current environment
CRAWLER_ENV = ENV.fetch('CRAWLER_ENV', 'development')

# Set up bundler
require 'rubygems'
require 'bundler'
Bundler.setup(:crawler, "crawler_#{CRAWLER_ENV}")

# Load common dependencies
require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies'

# Load crawler components
require 'crawler'
