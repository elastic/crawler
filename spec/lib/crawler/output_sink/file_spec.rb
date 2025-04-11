#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink::File) do
  let(:domains) { [{ url: 'http://example.com' }] }

  context '#initialize' do
    def new_sink(config)
      Crawler::OutputSink::File.new(config)
    end

    it 'has a default output directory of ./crawled_docs' do
      config = Crawler::API::Config.new(
        domains:,
        output_sink: './crawled_docs'
      )

      expect { new_sink(config) }.to_not raise_error
      expect(config.output_dir).to eq('./crawled_docs')
    end

    it 'should create the output directory' do
      dir = '/some/directory'
      config = Crawler::API::Config.new(
        domains:,
        output_sink: 'file',
        output_dir: dir
      )
      expect(FileUtils).to receive(:mkdir_p).with(dir)
      new_sink(config)
    end
  end
end
