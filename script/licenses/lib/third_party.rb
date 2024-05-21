#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'logger'

module ThirdParty
  LOGGER = Logger.new($stdout, level: Logger::DEBUG)

  LICENSE_FILE_NAME_OPTIONS = %w[
    LICENSE
    LICENSE.md
    LICENSE.txt
    License.txt
    LICENCE
    LICENSE-MIT
    Licence.md
    Licence.rdoc
    MIT_LICENSE
    MIT-LICENSE
    MIT-LICENSE.txt
    BSDL
    COPYING
    COPYING.txt
  ].freeze
  UNKNOWN_LICENSE = 'UNKNOWN'

  module SPDX
    class << self
      def normalize_license(license)
        return license if SUPPORTED_IDENTIFIERS.include?(license) || license.match?(/\s+OR|AND|WITH\s+/)

        ALIASES.fetch(license, nil)
      end
    end

    SUPPORTED_IDENTIFIERS = %w[
      0BSD
      Apache-2.0
      AFL-2.1
      BSD-2-Clause
      BSD-3-Clause
      CC0-1.0
      CC-BY-3.0
      CC-BY-4.0
      Elastic-2.0
      EPL-1.0
      ISC
      GPL-2.0
      LGPL-2.1
      MIT
      MPL-2.0
      Ruby
      Unlicense
    ].freeze

    IDENTIFIER_TO_ALIASES = {
      'AFL-2.1' => [
        'AFLv2.1'
      ],
      'BSD-2-Clause' => [
        'BSD 2-Clause',
        'BSD',
        'BSD*',
        '2-clause BSDL'
      ],
      'Apache-2.0' => [
        'Apache License Version 2.0',
        'Apache License (2.0)'
      ],
      'Ruby' => [
        'ruby'
      ],
      'Python-2.0' => [
        'PSFL'
      ],
      'MIT' => [
        'MIT*'
      ]
    }.freeze

    ALIASES = IDENTIFIER_TO_ALIASES.each_with_object({}) do |(spdx_identifier, aliases), out|
      aliases.each do |a|
        out[a] = spdx_identifier
      end
    end
  end
end

require_relative 'third_party/misc_dependencies'
require_relative 'third_party/rubygems_dependencies'
