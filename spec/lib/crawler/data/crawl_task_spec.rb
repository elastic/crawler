#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe Crawler::Data::CrawlTask do
  let(:url) { Crawler::Data::URL.parse('https://example.com/') }
  let(:task) { Crawler::Data::CrawlTask.new(url:, type: :content, depth: 1) }

  describe '#inspect' do
    it 'should return a nice representation of the object for logging' do
      expect(task.inspect).to be_a(String)
      expect(task.inspect).to match(/CrawlTask/)
    end
  end
end
