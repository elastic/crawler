#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::UrlQueue::MemoryOnly) do
  let(:domains) { ['http://example.com'] }
  let(:seed_urls) { ['http://example.com/'] }

  let(:config) do
    Crawler::API::Config.new(
      domain_allowlist: domains,
      seed_urls:,
      url_queue: :memory_only
    )
  end

  let(:queue) { described_class.new(config) }

  #-------------------------------------------------------------------------------------------------
  describe 'constructor' do
    it 'should require a config' do
      expect do
        described_class.new(nil)
      end.to raise_error(ArgumentError, 'Needs a config')
    end

    it 'should require the limit to be a positive number' do
      expect(config).to receive(:url_queue_size_limit).and_return(0)
      expect do
        described_class.new(config)
      end.to raise_error(ArgumentError, 'Queue size limit should be a positive number')
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#push' do
    it 'should accept an item and enqueue it' do
      item = double(:item)
      expect { queue.push(item) }.to change { queue.length }.by(1)
    end

    it 'should alert the operator when the queue is getting full' do
      expect(config).to receive(:url_queue_size_limit).and_return(11)

      system_logger = Logger.new($stdout)
      allow(queue).to receive(:system_logger).and_return(system_logger)
      expect(system_logger).to receive(:warn).with(/In-memory URL queue is \d+.*full/)

      item = double(:item)
      10.times { queue.push(item) }
    end

    it 'should reject the item if the queue is full' do
      expect(config).to receive(:url_queue_size_limit).and_return(1)
      item1 = double(:item)
      queue.push(item1)

      item2 = double(:item)
      expect { queue.push(item2) }.to raise_error(Crawler::Data::UrlQueue::QueueFullError)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#fetch' do
    it 'should return nil if the queue is empty' do
      expect(queue.fetch).to be_nil
    end

    it 'should return an item from the queue if the queue is not empty' do
      item = double(:item)
      queue.push(item)
      expect(queue.fetch).to be(item)
    end
  end
end
