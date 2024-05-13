#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'nokogiri' # https://github.com/sparklemotion/nokogiri/issues/2550

require 'factory_bot'

# Enable coverage information collection
require 'simplecov'
require 'simplecov-material'

SimpleCov.add_filter('spec')
SimpleCov.formatter = SimpleCov::Formatter::MaterialFormatter
SimpleCov.start

# Enforce the test environment in specs
ENV['CRAWLER_ENV'] = 'test'

# Disable external HTTP connections
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

# Load WebMock before crawler, so that proper mock http subclass is swapped in
WebMock.enable!

# Load the standalone crawler environment
require_relative '../lib/environment'

# Load the crawler itself
require 'crawler'

require_relative '../lib/crawler/cli'

# Require helper files
Dir["#{__dir__}/support/**/*.rb"].sort.each { |f| require f }

# Make it easier to use pry from specs, load it beforehand
require 'pry'

#---------------------------------------------------------------------------------------------------
# Set up the RSpec framework
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.include FactoryBot::Syntax::Methods
  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # This option causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # This allows you to limit a spec run to individual examples or groups
  # you care about by tagging them with `:focus` metadata. When nothing
  # is tagged with `:focus`, all examples get run. RSpec also provides
  # aliases for `it`, `describe`, and `context` that include `:focus`
  # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
  config.filter_run_when_matching :focus

  # Limits the available syntax to the non-monkey patched syntax that is recommended.
  config.disable_monkey_patching!

  # This setting enables warnings. It's recommended, but in some cases may
  # be too noisy due to issues in dependencies.
  config.warnings = true

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand(config.seed)
end
