# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'yaml'
require_relative '../../../../lib/crawler/cli/helpers'

RSpec.describe Crawler::CLI::Helpers do
  describe '.load_yaml' do
    let(:tmpfile) { Tempfile.new('config.yml') }

    after { tmpfile.close! }
  end

  describe '.nest_configs' do
    it 'returns an empty hash for nil/empty input' do
      expect(described_class.nest_configs(nil)).to eq({})
      expect(described_class.nest_configs({})).to eq({})
    end

    it 'unnests simple dot notation keys' do
      input = { 'a.b' => 1, 'c.d' => 2 }
      expected = { 'a' => { 'b' => 1 }, 'c' => { 'd' => 2 } }
      expect(described_class.nest_configs(input)).to eq(expected)
    end

    it 'unnests multiple levels of dot notation' do
      input = { 'a.b.c' => 1, 'x.y.z' => 'hello' }
      expected = { 'a' => { 'b' => { 'c' => 1 } }, 'x' => { 'y' => { 'z' => 'hello' } } }
      expect(described_class.nest_configs(input)).to eq(expected)
    end

    it 'handles mixed dot notation and regular keys' do
      input = { 'a.b' => 1, 'c' => 2, 'd.e.f' => 3 }
      expected = { 'a' => { 'b' => 1 }, 'c' => 2, 'd' => { 'e' => { 'f' => 3 } } }
      expect(described_class.nest_configs(input)).to eq(expected)
    end

    it 'merges keys with common prefixes' do
      input = { 'a.b' => 1, 'a.c' => 2 }
      expected = { 'a' => { 'b' => 1, 'c' => 2 } }
      expect(described_class.nest_configs(input)).to eq(expected)
    end

    it 'recursively unnests hashes within values' do
      input = {
        'top' => 1,
        'nested' => { 'a.b' => 2, 'c' => 3 },
        'deep.nest' => { 'x.y' => 4 }
      }
      expected = {
        'top' => 1,
        'nested' => { 'a' => { 'b' => 2 }, 'c' => 3 },
        'deep' => { 'nest' => { 'x' => { 'y' => 4 } } }
      }
      expect(described_class.nest_configs(input)).to eq(expected)
    end
  end
end
