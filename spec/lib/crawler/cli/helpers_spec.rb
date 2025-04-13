#
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

    it 'loads plain YAML without ERB' do
      tmpfile.write("---\nfoo: bar\nbaz: 1\n")
      tmpfile.rewind
      result = described_class.load_yaml(tmpfile.path)
      expect(result).to eq({ 'foo' => 'bar', 'baz' => 1 })
    end

    it 'loads YAML with ERB environment variable interpolation' do
      ENV['TEST_ENV_VAR'] = 'secret'
      tmpfile.write("---\napi_key: <%= ENV['TEST_ENV_VAR'] %>\n")
      tmpfile.rewind
      result = described_class.load_yaml(tmpfile.path)
      expect(result).to eq({ 'api_key' => 'secret' })
    end

    it 'loads YAML with ERB and Ruby default logic' do
      ENV.delete('MISSING_ENV_VAR')
      tmpfile.write("---\nvalue: <%= ENV['MISSING_ENV_VAR'] || 'default_value' %>\n")
      tmpfile.rewind
      result = described_class.load_yaml(tmpfile.path)
      expect(result).to eq({ 'value' => 'default_value' })
    end

    it 'raises error for invalid ERB syntax' do
      tmpfile.write("---\nfoo: <%= %invalid ruby %>\n")
      tmpfile.rewind
      expect do
        described_class.load_yaml(tmpfile.path)
      end.to raise_error(SyntaxError)
    end

    it 'raises error for invalid YAML after ERB' do
      tmpfile.write("---\nfoo: <%= 1 + %>\n")
      tmpfile.rewind
      expect do
        described_class.load_yaml(tmpfile.path)
      end.to raise_error(SyntaxError)
    end
  end
end
