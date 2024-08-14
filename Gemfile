# frozen_string_literal: true

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
  gem 'activesupport', '= 6.1.7.7'
  gem 'addressable', '>= 2.8.0'
  gem 'concurrent-ruby', '~> 1.1.4'
  gem 'dry-cli', '~> 0.7.0'
  gem 'elasticsearch', '~> 8.13.0'
  gem 'jar-dependencies', '0.4.1'
  gem 'json-schema', '~> 4.3.0'
  gem 'webrick', '~> 1.8.1'

  # Gems that need jruby as the platform
  gem 'bson', '~> 4.15.0', platform: :jruby
  gem 'bigdecimal', '~> 3.1.7', platform: :jruby
  gem 'json', '~> 2.7.2', platform: :jruby
  gem 'nokogiri', '= 1.13.10', platform: :jruby
  gem 'racc', '~> 1.7.3', platform: :jruby
  gem 'strscan', '~> 3.1.0', platform: :jruby
  gem 'thread_safe', '~> 0.3.6', platform: :jruby

  # override ipaddr 1.2.2 that comes from jruby-jars 9.3.3.0
  # issue https://github.com/elastic/enterprise-search-team/issues/2137
  # it can be removed when jruby-jars includes ipaddr ~> 1.2.4
  gem 'ipaddr', '~> 1.2.4'

  # We need to bundle TZ data because on windows and in some minimal Linux installations there is
  # no system-level TZ data info and the app blows up when trying to use timezone information
  # See https://github.com/tzinfo/tzinfo/wiki/Resolving-TZInfo::DataSourceNotFound-Errors for details
  gem 'tzinfo-data', '~> 1.2024.1'

  # Local gem for testing fake sites
  gem 'faux', path: 'vendor/faux', require: false
end

group :development do
  gem 'rubocop', '~> 1.63'
  gem 'rubocop-performance', '1.11.5'
  gem 'ruby-debug-ide'
  gem 'ruby-debug-base', '0.11.0', platform: :jruby
  gem 'pry-remote'
  gem 'pry-nav'
end

group :test do
  gem 'rspec', '~> 3.13.0'
  gem 'webmock'
  gem 'simplecov'
  gem 'simplecov-material', require: false
end

group :development, :test do
  gem 'rack', '~> 2.2.8.1'
  gem 'httpclient'
  gem 'pry', '~> 0.14.2', platform: :jruby
  gem 'factory_bot', '~> 6.2.0', require: false
end
