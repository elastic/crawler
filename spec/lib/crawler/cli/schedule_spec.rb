#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::CLI::Schedule) do
  describe '.call' do
    let(:cli) { Dry::CLI(Crawler::CLI) }

    # Dry::CLI expects the command name to be the basename of the program
    let(:cmd) { File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME)) }

    context 'when crawl config is not provided' do
      it 'shows an error message' do
        output = capture_error { cli.call(arguments: ['schedule']) }
        expect(output).to include("ERROR: \"#{cmd} schedule\" was called with no arguments")
        expect(output).to include("Usage: \"#{cmd} schedule CRAWL_CONFIG\"")
      end
    end

    context 'when a wrong crawl config is provided' do
      let(:crawl_config) { 'spec/fixtures/non-existent-crawl.yml' }
      it 'shows an error message' do
        output = capture_output { cli.call(arguments: ['schedule', crawl_config]) }
        expect(output).to include("ERROR: Config file #{crawl_config} does not exist!")
      end
    end

    context 'when a crawl config is provided' do
      let(:crawl_config) { 'spec/fixtures/crawl.yml' }
      let(:crawl_mock) { double }
      let(:scheduler_mock) { double }

      before(:example) do
        allow(Crawler::API::Crawl).to receive(:new).and_return(crawl_mock)
        allow(Rufus::Scheduler).to receive(:new).and_return(scheduler_mock)
        allow(scheduler_mock).to receive(:cron)
        allow(scheduler_mock).to receive(:join)
      end

      it 'runs a crawl' do
        expect(scheduler_mock).to receive(:cron).with('* * * * *', overlap: false).once

        capture_output { cli.call(arguments: ['schedule', crawl_config]) }
      end
    end

    it 'shows help page' do
      output = capture_output { cli.call(arguments: ['schedule', '-h']) }
      expected_output = <<~OUTPUT
        Command:
          #{cmd} schedule

        Usage:
          #{cmd} schedule CRAWL_CONFIG

        Description:
          Schedule a recurring crawl of the site

        Arguments:
          CRAWL_CONFIG                      # REQUIRED Path to crawl config file

        Options:
          --es-config=VALUE                 # Path to elasticsearch config file
          --help, -h                        # Print this help
      OUTPUT

      expect(output).to eq(expected_output)
    end
  end
end
