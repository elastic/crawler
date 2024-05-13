#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::CLI::Version) do
  describe '.call' do
    let(:version_path) { File.expand_path('../../../../product_version', __dir__) }

    it 'prints the current version from product_version_file' do
      expect(File).to receive(:read).with(version_path).and_return('1.0.0')
      expect { described_class.new.call }.to output("1.0.0\n").to_stdout
    end
  end
end
