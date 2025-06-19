#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Logging::CrawlLogger) do
  let(:stdout_log_handler) { Crawler::Logging::Handler::StdoutHandler.new('debug') }

  context 'when a fresh CrawlLogger is created' do
    it 'should initialize with no log handlers' do
      expect(
        Crawler::Logging::CrawlLogger.new.instance_variable_get(:@all_handlers)
      ).to be_empty
    end

    it 'should add log handlers to the all_handlers array' do
      crawl_logger = Crawler::Logging::CrawlLogger.new
      crawl_logger.add_handler(stdout_log_handler)

      expect(
        crawl_logger.instance_variable_get(:@all_handlers)
      ).to eq([stdout_log_handler])
    end
  end

  context 'when CrawlLogger is set up with at least one handler' do
    let(:crawl_logger) { Crawler::Logging::CrawlLogger.new }
    let(:tags) { ['crawl: 0451', 'primary'] }
    before do
      crawl_logger.add_handler(stdout_log_handler)

      allow(Crawler::Logging::CrawlLogger).to receive(:new).and_return(crawl_logger)
      allow(crawl_logger).to receive(:debug).and_call_original
      allow(crawl_logger).to receive(:info).and_call_original
      allow(crawl_logger).to receive(:warn).and_call_original
      allow(crawl_logger).to receive(:error).and_call_original
      allow(crawl_logger).to receive(:fatal).and_call_original
      allow(crawl_logger).to receive(:add).and_call_original
      allow(crawl_logger).to receive(:<<).and_call_original
      allow(crawl_logger).to receive(:route_logs_to_handlers).and_call_original
      allow(crawl_logger).to receive(:add_tags_to_log_handlers).and_call_original

      allow(stdout_log_handler).to receive(:log).and_call_original
      allow(stdout_log_handler).to receive(:add_tags).and_call_original
    end

    it 'should be route incoming log requests to the handlers with correct log level' do
      crawl_logger.debug('Some debug log message')
      crawl_logger.info('Some info log message')
      crawl_logger.warn('Some warn log message')
      crawl_logger.error('Some error log message')
      crawl_logger.fatal('Some fatal log message')
      crawl_logger.add(Logger::INFO, 'Some info log message')
      crawl_logger << 'Some non-leveled message'

      expect(crawl_logger).to have_received(:route_logs_to_handlers).with(
        'Some debug log message', Logger::DEBUG
      )
      expect(crawl_logger).to have_received(:route_logs_to_handlers).with(
        'Some info log message', Logger::INFO
      ).twice
      expect(crawl_logger).to have_received(:route_logs_to_handlers).with(
        'Some warn log message', Logger::WARN
      )
      expect(crawl_logger).to have_received(:route_logs_to_handlers).with(
        'Some error log message', Logger::ERROR
      )
      expect(crawl_logger).to have_received(:route_logs_to_handlers).with(
        'Some fatal log message', Logger::FATAL
      )
      expect(crawl_logger).to have_received(:route_logs_to_handlers).with(
        'Some non-leveled message', nil
      )

      expect(stdout_log_handler).to have_received(:log).exactly(7).times
    end

    it 'should call the add_tags() method of the log handlers' do
      crawl_logger.add_tags_to_log_handlers(tags)

      expect(stdout_log_handler).to have_received(:add_tags)
    end
  end
end
