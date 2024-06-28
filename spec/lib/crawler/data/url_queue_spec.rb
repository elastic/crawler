#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::UrlQueue) do
  let(:domains) { [{ url: 'http://example.com' }] }

  let(:config) do
    Crawler::API::Config.new(
      domains:
    )
  end

  describe '.create' do
    it 'should return a queue object' do
      queue = Crawler::Data::UrlQueue.create(config)
      expect(queue).to be_kind_of(Crawler::Data::UrlQueue::Base)
    end
  end
end
