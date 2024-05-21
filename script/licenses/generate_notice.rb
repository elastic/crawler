#!/usr/bin/env ruby

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

NOTICE_TXT_PATH = File.expand_path('../../NOTICE.txt', __dir__)

require_relative 'lib/third_party'

def write_header_to_file(io)
  io.puts 'Elastic Open Web Crawler'
  io.puts 'Copyright 2024 Elasticsearch B.V.'
  io.puts
  io.puts 'The Elastic Open Web Crawler contains the following third-party dependencies:'
  io.puts
end

def write_license_to_file(io, klass_instance, identifier, dependency)
  io.puts '-' * 80
  io.puts "Library: #{klass_instance.format_library_for_notice_txt(identifier, dependency)}"
  io.puts "URL: #{dependency[:url]}" if dependency[:url]
  io.puts "License: #{dependency[:license]}" if dependency[:license]
  io.puts
  File.open(dependency[:license_file_path], 'r') do |license_file|
    io.puts(license_file.read)
    io.puts
  end
end

File.open(NOTICE_TXT_PATH, 'w') do |io|
  write_header_to_file(io)

  [
    ThirdParty::RubygemsDependencies,
    ThirdParty::MiscDependencies
  ].each do |klass|
    klass_instance = klass.new
    dependencies = klass_instance.get(with_license_files: true)
    dependencies.keys.sort.each do |identifier|
      dependency = dependencies.fetch(identifier)

      unless dependency[:license_file_path]
        ThirdParty::LOGGER.error("There is no license file for #{identifier}!")
        exit(1)
      end

      unless File.exist?(dependency[:license_file_path])
        err = "License file for #{identifier} does not exist locally (path: #{dependency[:license_file_path]})"
        ThirdParty::LOGGER.error(err)
        exit(2)
      end

      write_license_to_file(io, klass_instance, identifier, dependency)
    end
  end
end
