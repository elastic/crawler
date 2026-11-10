#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Agent::CrawlRunner) do
  let(:logger) { instance_double(Crawler::Logging::CrawlLogger, info: nil, error: nil) }
  let(:config) { Crawler::API::Config.new(domains: [{ url: 'http://example.com' }], output_sink: :console, log_level: 'error') }
  let(:changes) { [] }
  let(:release) { Queue.new }
  let(:crawl) { instance_double(Crawler::API::Crawl, outcome: :success, outcome_message: 'done') }

  subject(:runner) { described_class.new(logger:, on_change: ->(status) { changes << status }) }

  before do
    allow(Crawler::API::Crawl).to receive(:new).with(config).and_return(crawl)
    allow(crawl).to receive(:start!) { release.pop }
  end

  it 'runs a crawl in the background and reports status changes' do
    status = runner.start(config, trigger: 'action')
    expect(status).to include(crawl_id: config.crawl_id, status: 'running', trigger: 'action')
    expect(status[:started_at]).to match(/\d{4}-\d{2}-\d{2}T/)
    expect(runner).to be_running
    expect(changes).to eq([status])

    release << :go
    runner.wait(5)
    wait_until { changes.size == 2 }

    expect(runner).not_to be_running
    expect(runner.status).to include(status: 'success', message: 'done')
    expect(runner.status[:finished_at]).to match(/\d{4}-\d{2}-\d{2}T/)
  end

  it 'rejects a second crawl while one is in progress' do
    runner.start(config, trigger: 'schedule')
    expect { runner.start(config, trigger: 'action') }
      .to raise_error(Crawler::Agent::ActionError, /already in progress \(crawl id: #{config.crawl_id}\)/)
  ensure
    release << :go
    runner.wait(5)
  end

  it 'asks the crawl to shut down on stop' do
    runner.start(config, trigger: 'action')
    expect(crawl).to receive(:start_shutdown!).with(reason: 'bye') { release << :go }
    runner.stop(reason: 'bye')
    runner.wait(5)
  end

  it 'reports failures when the crawl cannot be created' do
    allow(Crawler::API::Crawl).to receive(:new).and_raise(ArgumentError, 'bad sink')
    runner.start(config, trigger: 'action')
    runner.wait(5)
    expect(runner.status).to include(status: 'failure', message: 'bad sink')
  end

  it 'reports failures when the crawl exits because Elasticsearch is unreachable' do
    allow(crawl).to receive(:start!).and_raise(Errors::ExitIfESConnectionError, 'Failed to reach ES at es:9200: [403]')
    runner.start(config, trigger: 'action')
    runner.wait(5)
    expect(runner).not_to be_running
    expect(runner.status).to include(status: 'failure', message: 'Failed to reach ES at es:9200: [403]')
  end

  it 'has no status before the first crawl' do
    expect(runner.status).to be_nil
    expect(runner).not_to be_running
    expect(runner.stop(reason: 'x')).to be_nil
  end
end
