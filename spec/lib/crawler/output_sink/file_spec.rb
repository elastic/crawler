#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink::File) do
  let(:domains) { ['http://example.com'] }
  let(:seed_urls) { ['http://example.com/'] }

  context '#initialize' do
    def new_sink(config)
      Crawler::OutputSink::File.new(config)
    end

    it 'should require an output directory' do
      config = Crawler::API::Config.new(
        domain_allowlist: domains,
        seed_urls:,
        output_sink: 'file'
      )

      expect { new_sink(config) }.to raise_error(/Missing or invalid output directory/)
    end

    it 'should create the output directory' do
      dir = '/some/directory'
      config = Crawler::API::Config.new(
        domain_allowlist: domains,
        seed_urls:,
        output_sink: 'file',
        output_dir: dir
      )
      expect(FileUtils).to receive(:mkdir_p).with(dir)
      new_sink(config)
    end
  end
end
