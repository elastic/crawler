#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink) do
  let(:domains) { [{ url: 'http://example.com' }] }

  context '.create' do
    it 'should validate the sync name' do
      config = Crawler::API::Config.new(
        domains:,
        output_sink: 'magnetic-tape'
      )

      expect do
        Crawler::OutputSink.create(config)
      end.to raise_error(/Unknown output sink/)
    end

    it 'should return a new sink object of a correct type' do
      config = Crawler::API::Config.new(
        domains:,
        output_sink: 'console'
      )

      sink = Crawler::OutputSink.create(config)
      expect(sink).to be_kind_of(Crawler::OutputSink::Console)
    end
  end
end
