# frozen_string_literal: true

# 6.1
gem 'rails-html-sanitizer', '= 1.5.0'
gem 'thread_safe', '= 0.3.6'

# def rails_next?
#   File.basename(__FILE__) == 'Gemfile_rails_next'
# end
#
# def rails_current?
#   !rails_next?
# end
#
# #---------------------------------------------------------------------------------------------------
# # Unless we are in a deployment mode or are running from a script bundle, show a warning
# is_install_or_update = (ARGV.empty? || ARGV.include?('install') || ARGV.include?('update'))
# not_deployment_mode = !ARGV.include?('--deployment')
#
# if File.basename($PROGRAM_NAME) == 'bundle' && is_install_or_update && not_deployment_mode && !ENV['SCRIPT_BUNDLE'] && !$printed_bundle_warning
#   require_relative 'script/support/string_colors'
#   puts
#   puts 'WARNING: You seem to be running a bundle install command directly. This is not recommended.'.yellow
#   puts
#   puts "Please note: You need to use the #{'./script/bundle'.yellow} script for managing gems to ensure proper rubygems caching within the repository."
#   puts 'If you are in a deployment/CI situation, please use the --deployment flag for bundle install'
#   puts
#
#   # Only show the warning once
#   $printed_bundle_warning = true
# end

#---------------------------------------------------------------------------------------------------
jruby_version = File.read(File.join(__dir__, '.ruby-version')).strip.delete_prefix('jruby-')
supported_bundler_version = "~> #{File.read(File.join(__dir__, '.bundler-version')).strip}"

ALL_DEVELOPMENT_ENVS = %i[development crawler_development]
ALL_TEST_ENVS = %w[test crawler_test]

#---------------------------------------------------------------------------------------------------
# Pull gem index from rubygems
source 'https://rubygems.org'

# Pin the version of bundle we support
gem 'bundler', supported_bundler_version

#---------------------------------------------------------------------------------------------------
# Default dependencies for all environments (including the crawler)
#---------------------------------------------------------------------------------------------------
group :default, :crawler do
  gem 'addressable', '>= 2.8.0'
  gem 'bson', '~> 4.2.2'
  gem 'concurrent-ruby', '~> 1.1.4'
  gem 'elasticsearch', '~> 8.12.2'
  gem 'nokogiri', '= 1.13.10', :require => false
  gem 'mail', '2.7.1'
  gem 'rake', '~> 12.3.2'

  # if rails_next?
  #   gem 'rails', '= 6.1.7.5'
  # else
  #   gem 'rails', '= 6.1.7.5'
  # end
  #
  # gem 'i18n', '1.6'

  # We need to bundle TZ data because on windows and in some minimal Linux installations there is
  # no system-level TZ data info and the app blows up when trying to use timezone information
  # See https://github.com/tzinfo/tzinfo/wiki/Resolving-TZInfo::DataSourceNotFound-Errors for details
  gem 'tzinfo-data'

  # Used for config file validation
  gem 'json-schema'
end

#---------------------------------------------------------------------------------------------------
# Default dependencies for all Rails environments (but not for the crawler)
#---------------------------------------------------------------------------------------------------
# gem 'fishwife-servlet', :path => 'vendor/fishwife-servlet', :platform => 'jruby', :require => false
#
# # If you update this gem, please update the sprockets_rails.rb initializer as well
# gem 'sprockets-rails', '~> 2'
# gem 'sprockets', '~> 3.7.2'
# gem 'webpacker', '~> 5.4.3'
#
# gem 'jquery-rails', '~> 4.4.0'
#
# gem 'devise', '~> 4.7.1'
# gem 'devise-token_authenticatable', '~> 1.1.0'
#
# gem 'ipaddress'
# gem 'hashie', '~> 4.1.0'
#
# gem 'uea-stemmer'
# gem 'stringex', :require => 'stringex_lite'
#
# gem 'state_machines', '~> 0.5.0'
# gem 'state_machines-activemodel', '~> 0.8.0'
#
# gem 'manticore', '~> 0.7.0', :platform => 'jruby'
# gem 'httpclient'
# gem 'faraday', '~> 1.10.2'
# gem 'faraday_middleware', '= 1.2.0'
#
# gem 'statsd-instrument', '= 2.1.1'
#
# # Make sure Fishwife::RackServlet works with newer versions before upgrading to 2.2.x
# gem 'rack', '~> 2.2.6.4'
# gem 'rack-attack', '>= 6.6.0'
#
# gem 'rack-ssl-enforcer'
# gem 'cancancan'
#
# gem 'jwt', '~> 1.5.1'
#
# gem 'file-tail'

# Security updates
gem 'rack-cors', '~> 1.0.4', :require => 'rack/cors'
gem 'json', '~> 2.3.1'

# Used in multiple places around the codebase (see all the references to Zip::File)
# gem 'rubyzip', '~> 2.0.0', :require => 'zip'

# gem 'awesome_print', '~> 1.8.0'
#
# gem 'htmlentities'
# gem 'mime-types', '= 3.1'

# gem 'gson', :platform => 'jruby'

# gem 'childprocess', '3.0.0'

# Frito Pie
# gem 'signet', '0.14'
# gem 'octokit', '4.25.1'
# gem 'google-apis-drive_v3', '0.16.0'
# gem 'google-apis-gmail_v1', '0.11.0'
# gem 'google-apis-admin_directory_v1', '0.17.0'
# gem 'google-apis-oauth2_v2', '0.6.0'
# gem 'memoist', '0.16.0'
# gem 'zendesk_api', '1.28.0'
# gem 'restforce', '5.0.4'
# gem 'marcel', '~> 1.0', '>= 1.0.1'

# Connectors
# gem 'salesforce_bulk_query', :git => 'git@github.com:adam-harwood/salesforce_bulk_query', :ref => 'a51c4958d53f9ce33edf6e9f78206f54fbf0bf35'

# Load Elastic APM agent
# gem 'elastic-apm'

# Elastic APM dependency, need a version that works with warbler
# 4.2+ uses http-parser, which does not work with warbler: https://github.com/jruby/warbler/issues/482
# 5.0+ uses llhttp-ffi, which is supposed to work, but still does not work with warbler...
# gem 'http', '< 4.2'

# Elastic APM dependencies, need it here to help bundler pick the right platform for the gems
# gem 'http_parser.rb', '~> 0.6.0', :platform => 'jruby'
# gem 'unf', :platform => 'jruby'
#
# gem 'doorkeeper', '4.4.3'
#
# gem 'pr_geohash'
#
# gem 'connectors_utility', '8.10.0.0'

# override ipaddr 1.2.2 that comes from jruby-jars 9.3.3.0
# issue https://github.com/elastic/enterprise-search-team/issues/2137
# it can be removed when jruby-jars includes ipaddr ~> 1.2.4
gem 'ipaddr', '~> 1.2.4'

#---------------------------------------------------------------------------------------------------
# Rails engines for ent-search modular monolith
#---------------------------------------------------------------------------------------------------
# group :monolith_engines do
#   gem 'actastic', path: 'actastic'
# end

#---------------------------------------------------------------------------------------------------
# Crawler-only default dependencies
#---------------------------------------------------------------------------------------------------
# This group acts as a default group for standalone crawler scripts/tests/etc
group :crawler do
  gem 'faux', :path => 'vendor/faux', :require => false
end

#---------------------------------------------------------------------------------------------------
# Special-case dependencies
#---------------------------------------------------------------------------------------------------
# Dependencies used on CI for building Rails assets
# group :assets do
#   gem 'uglifier', '>= 1.0.3'
#   gem 'sass-rails', '~> 5.1'
#   gem 'autoprefixer-rails'
# end

# Dependencies used on CI to build war files for self-managed production deployments
# group :togo_not_bundled do
#   gem 'jruby-jars', jruby_version, :require => false
#
#   # using warbler ref that includes a fix of ours, until they release a new version. See: https://github.com/jruby/warbler/pull/491 and https://github.com/elastic/enterprise-search-team/issues/464#issuecomment-877819309
#   gem 'warbler', :require => false, :git => 'git@github.com:jruby/warbler.git', :ref => '772ac94e47c8bcba030cbf045be9b8ebd40fe28b'
# end

#---------------------------------------------------------------------------------------------------
# Development dependencies for Rails environments (but not for the crawler)
#---------------------------------------------------------------------------------------------------
group :development do
  gem 'execjs'
  gem 'ruby-maven', :require => false

  # Add ffaker to create fake people in demo accounts
  gem 'ffaker'
  gem 'rails-erd', :require => false
end

#---------------------------------------------------------------------------------------------------
# Development and test dependencies for all environments (including the crawler)
#---------------------------------------------------------------------------------------------------
group(*ALL_DEVELOPMENT_ENVS) do
  # gem 'ent-search-ci', '7.16.3'
  gem 'rubocop', '1.18.4'
  gem 'rubocop-performance', '1.11.5'
  gem 'rubocop-rails', '2.11.3'

  gem 'ruby-debug-ide'
  gem 'pry-remote'
  gem 'pry-nav'
  gem 'ruby-debug-base', '0.11.0', :platform => 'jruby'

  gem 'tty-prompt', :require => false
end

group(*ALL_TEST_ENVS) do
  # Warning: Keep this version in sync with spec/fixtures/shared_togo/jetty_server/simple_web_app/Gemfile
  # Otherwise, JettyServer specs will fail on CI
  gem 'test-unit', '= 3.3.6'

  gem 'rspec-core', '~> 3.10.1'
  gem 'rspec-rails', '~> 4.0.2'
  gem 'rspec-collection_matchers', '~> 1.2.0'
  gem 'rspec_junit_formatter'

  gem 'webmock'
  gem 'vcr', '~> 6.1.0'
  gem 'climate_control'

  gem 'timecop'
  gem 'simplecov', :require => false
  gem 'simplecov-material', :require => false
  gem 'oas_parser'
end

group(*ALL_DEVELOPMENT_ENVS, *ALL_TEST_ENVS) do
  gem 'pry'
  gem 'factory_bot_rails', '~> 6.2.0', :require => false

  gem 'rb-fsevent', :require => false
  gem 'rb-inotify', :require => false
  gem 'listen', '~> 1.0'

  gem 'ejson'
end

#---------------------------------------------------------------------------------------------------
# Test dependencies for Rails environments (but not for the crawler)
#---------------------------------------------------------------------------------------------------
# group :test do
#   gem 'rack-test', '~> 1.1.0'
#   gem 'rswag-specs', '~> 2.4.0'
#
#   # Used for checking migration fixtures against ES state
#   gem 'json-diff'
# end
