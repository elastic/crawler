#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink) do
  let(:domains) { [{ url: 'http://example.com' }] }

  let(:es_client) { double }
  let(:es_client_indices) { double(:es_client_indices, get: double) }

  before(:each) do
    allow(ES::Client).to receive(:new).and_return(es_client)
    allow(es_client).to receive(:indices).and_return(es_client_indices)
  end

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
        output_sink: :elasticsearch,
        output_index: 'some-index-name',
        elasticsearch: {
          host: 'http://localhost',
          port: 1234,
          api_key: 'key'
        }
      )

      sink = Crawler::OutputSink.create(config)
      expect(sink).to be_kind_of(Crawler::OutputSink::Elasticsearch)
    end
  end
end
