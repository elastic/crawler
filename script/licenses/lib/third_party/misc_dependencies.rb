#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'pathname'
require_relative 'base'

module ThirdParty
  class MiscDependencies < Base
    def type
      'Misc. Dependency'
    end

    def licenses_path
      LICENSES_PATH
    end

    def license_fallbacks
      {}
    end

    def license_file_fallbacks
      DEPENDENCIES.transform_values do |dependency|
        dependency.fetch(:license_file_override)
      end
    end

    def get(with_license_files: false)
      DEPENDENCIES.each_with_object({}) do |(identifier, dependency), out|
        out[identifier] = dependency.slice(:name, :version, :license, :url)

        out[identifier][:license_file_path] = license_file_path_for_dependency(identifier) if with_license_files
      end
    end

    LICENSES_PATH = Pathname.new(__dir__).join('..', '..', 'misc_licenses')
    JRUBY_VERSION = File.read(File.expand_path('../../../../.ruby-version', __dir__)).strip.delete_prefix('jruby-')

    DEPENDENCIES = {
      'jruby' => {
        name: 'jruby',
        version: JRUBY_VERSION,
        license: 'EPL-2.0 OR GPL-2.0 OR LGPL-2.1',
        license_file_override: { manually_added: true },
        url: 'https://www.jruby.org'
      },
      'tika' => {
        name: 'tika',
        version: '1.23',
        license: 'Apache-2.0',
        license_file_override: { manually_added: true },
        url: 'https://github.com/apache/tika'
      }
    }.freeze
  end
end
