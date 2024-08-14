#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'bundler'
require 'pathname'
require_relative 'base'

module ThirdParty
  class RubygemsDependencies < Base
    def type
      'Ruby Gem'
    end

    def licenses_path
      LICENSES_PATH
    end

    def license_fallbacks
      LICENSE_FALLBACKS
    end

    def license_file_fallbacks
      LICENSE_FILE_FALLBACKS
    end

    def license_hash(spec, identifier)
      {
        name: spec.name,
        version: spec.version,
        license: spdx_license_for_dependency(identifier, spec.licenses) || UNKNOWN_LICENSE,
        url: spec.homepage || URL_FALLBACKS[spec.name]
      }
    end

    def get_license_file_path(spec)
      LICENSE_FILE_NAME_OPTIONS.lazy.map do |license_name|
        Dir[File.join(spec.full_gem_path, license_name)].first
      end.find(&:itself)
    end

    def get(with_license_files: false)
      Bundler.definition.specs_for(%i[default togo_not_bundled]).each_with_object({}) do |spec, out|
        identifier = spec.name

        out[identifier] = license_hash(spec, identifier)

        next unless with_license_files

        license_file_path = get_license_file_path(spec)
        out[spec.name][:license_file_path] = license_file_path || license_file_path_for_dependency(identifier)
      end
    end

    LICENSES_PATH = Pathname.new(__dir__).join('..', '..', 'rubygems_licenses')

    # These gems have not specified a license in their gemspecs so we had to
    # manually infer which license they are on by inspecting the LICENSE file.
    LICENSE_FALLBACKS = {
      # https://github.com/rubygems/bundler/blob/f66c3346733afeeff3ac4b09f522fe40bc8dbb44/bundler.gemspec#L10
      'bundler' => 'MIT',

      # (Vendored ES gem, repo not open yet) vendor/faux
      'faux' => 'MIT',

      # https://github.com/avsej/gson.rb/blob/0.6.1/LICENSE
      'gson' => 'Apache-2.0',

      # https://github.com/mkristian/jar-dependencies/blob/master/MIT-LICENSE
      'jar-dependencies' => 'MIT',

      # https://github.com/jm/rack-mount/blob/master/MIT-LICENSE
      'rack-mount' => 'MIT',

      # https://github.com/ruby/ruby2_keywords/blob/master/LICENSE
      'ruby2_keywords' => 'BSD-2-Clause',

      # https://github.com/ruby/strscan/blob/master/LICENSE.txt
      'strscan' => 'BSD-2-Clause'
    }.freeze

    URL_FALLBACKS = {
      # https://github.com/rubygems/bundler/blob/f66c3346733afeeff3ac4b09f522fe40bc8dbb44/bundler.gemspec#L18
      'bundler' => 'http://bundler.io'
    }.freeze

    # These gems are missing a license file in the gem build but we can instead
    # download a license from the repo.
    LICENSE_FILE_FALLBACKS = {
      # https://github.com/bundler/bundler/tree/v1.16.6
      'bundler' => { url: 'https://raw.githubusercontent.com/bundler/bundler/v1.16.6/LICENSE.md' },

      # ES gem from private repo. MIT licensed, see vendor/faux
      'faux' => { manually_added: true },

      # https://github.com/nahi/httpclient/blob/v2.8.3/README.md#license
      # Ruby licensed gem but there is no license file, besides a License section in the README.
      'httpclient' => { manually_added: true },

      # https://github.com/mkristian/jar-dependencies/blob/master/MIT-LICENSE
      'jar-dependencies' => { url: 'https://raw.githubusercontent.com/mkristian/jar-dependencies/master/MIT-LICENSE' },

      # https://github.com/jruby/jruby/blob/9.2.9.0/maven/jruby-jars/README.txt
      # The license is included in the README.
      'jruby-jars' => { manually_added: true },

      # https://github.com/flori/json/tree/v1.8.6
      # Ruby licensed gem but there is no license file until later vesions.
      'json' => { url: 'https://raw.githubusercontent.com/flori/json/v2.3.0/LICENSE' },

      # https://github.com/seattlerb/minitest/blob/v5.11.3/README.rdoc
      # MIT licensed gem but the license is included in the README.
      'minitest' => { manually_added: true },

      # https://github.com/ruby/racc/blob/v1.5.2/COPYING
      'racc' => { url: 'https://raw.githubusercontent.com/ruby/racc/v1.5.2/COPYING' },

      # https://github.com/jm/rack-mount/blob/master/MIT-LICENSE
      'rack-mount' => { url: 'https://raw.githubusercontent.com/jm/rack-mount/master/MIT-LICENSE' },

      # https://github.com/ruby/ruby2_keywords/blob/master/LICENSE
      'ruby2_keywords' => { url: 'https://raw.githubusercontent.com/ruby/ruby2_keywords/master/LICENSE' },

      # https://github.com/ruby/webrick/blob/master/webrick.gemspec#L65
      # BSD-2-Clause licensed gem
      'webrick' => { url: 'http://www.ruby-lang.org/en/LICENSE.txt' },

      # https://github.com/ruby/strscan/blob/master/LICENSE.txt
      'strscan' => { url: 'https://github.com/ruby/strscan/blob/master/LICENSE.txt' }
    }.freeze
  end
end
