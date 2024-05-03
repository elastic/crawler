#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

# Add the lib directory to the load path
$LOAD_PATH << __dir__.to_s

# Calculate the current environment
CRAWLER_ENV = ENV.fetch('CRAWLER_ENV', 'development')

# Set up bundler
require 'rubygems'
require 'bundler'
Bundler.setup(:default, CRAWLER_ENV)

# Load common dependencies
require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies'

# Load crawler components
require 'crawler'
