# frozen_string_literal: true

# 6.1
gem 'thread_safe', '= 0.3.6'

# # Unless we are in a deployment mode or are running from a script bundle, show a warning
is_install_or_update = (ARGV.empty? || ARGV.include?('install') || ARGV.include?('update'))
not_deployment_mode = !ARGV.include?('--deployment')

if File.basename($PROGRAM_NAME) == 'bundle' && is_install_or_update && not_deployment_mode && !ENV['SCRIPT_BUNDLE'] && !$printed_bundle_warning
  require_relative 'script/support/string_colors'
  puts
  puts 'WARNING: You seem to be running a bundle install command directly. This is not recommended.'.yellow
  puts
  puts "Please note: You need to use the #{'./script/bundle'.yellow} script for managing gems to ensure proper rubygems caching within the repository."
  puts 'If you are in a deployment/CI situation, please use the --deployment flag for bundle install'
  puts
  # Only show the warning once
  $printed_bundle_warning = true
end

supported_bundler_version = "~> #{File.read(File.join(__dir__, '.bundler-version')).strip}"

source 'https://rubygems.org'
gem 'bundler', supported_bundler_version

group :default do
  gem 'addressable', '>= 2.8.0'
  gem 'bson', '~> 4.2.2'
  gem 'concurrent-ruby', '~> 1.1.4'
  gem 'elasticsearch', '~> 8.13.0'
  gem 'nokogiri', '= 1.13.10', :require => false
  gem 'mail', '2.7.1'
  gem 'rake', '~> 12.3.2'
  gem 'json-schema'

  # Local gem for testing fake sites
  gem 'faux', :path => 'vendor/faux', :require => false

  # We need to bundle TZ data because on windows and in some minimal Linux installations there is
  # no system-level TZ data info and the app blows up when trying to use timezone information
  # See https://github.com/tzinfo/tzinfo/wiki/Resolving-TZInfo::DataSourceNotFound-Errors for details
  gem 'tzinfo-data'
end

gem 'rack-cors', '~> 1.0.4', :require => 'rack/cors'
gem 'json', '~> 2.3.1'
gem 'jar-dependencies', '0.4.1'

# override ipaddr 1.2.2 that comes from jruby-jars 9.3.3.0
# issue https://github.com/elastic/enterprise-search-team/issues/2137
# it can be removed when jruby-jars includes ipaddr ~> 1.2.4
gem 'ipaddr', '~> 1.2.4'

group :development do
  gem 'rubocop', '1.18.4'
  gem 'rubocop-performance', '1.11.5'

  gem 'ruby-debug-ide'
  gem 'pry-remote'
  gem 'pry-nav'
  gem 'ruby-debug-base', '0.11.0', :platform => 'jruby'

  gem 'tty-prompt', :require => false
end

group :test do
  gem 'test-unit', '= 3.3.6'
  gem 'rspec', '~> 3.13.0'
  gem 'webmock'
  gem 'vcr', '~> 6.1.0'
  gem 'climate_control'
  gem 'timecop'
  gem 'simplecov', :require => false
  gem 'simplecov-material', :require => false
  gem 'oas_parser'
end

group :development, :test do
  gem 'pry'
  gem 'factory_bot', '~> 6.2.0', :require => false
  gem 'rb-fsevent', :require => false
  gem 'rb-inotify', :require => false
  gem 'listen', '~> 1.0'
  gem 'ejson'
end
