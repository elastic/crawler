#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::CLI::Crawl) do
  describe '.call' do
    let(:cli) { Dry::CLI(Crawler::CLI) }

    # Dry::CLI expects the command name to be the basename of the program
    let(:cmd) { File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME)) }

    context 'when crawl config is not provided' do
      it 'shows an error message' do
        output = capture_error { cli.call(arguments: ['crawl']) }
        expect(output).to include("ERROR: \"#{cmd} crawl\" was called with no arguments")
        expect(output).to include("Usage: \"#{cmd} crawl CRAWL_CONFIG\"")
      end
    end

    context 'when a wrong crawl config is provided' do
      let(:crawl_config) { 'spec/fixtures/non-existent-crawl.yml' }
      it 'shows an error message' do
        output = capture_output { cli.call(arguments: ['crawl', crawl_config]) }
        expect(output).to include("ERROR: Config file #{crawl_config} does not exist!")
      end
    end

    context 'when a crawler config is provided' do
      let(:crawl_config) { 'spec/fixtures/crawl.yml' }
      let(:crawl_mock) { double }

      before(:example) do
        allow(crawl_mock).to receive(:start!).and_return(true)
      end

      it 'runs a crawl' do
        allow(Crawler::API::Crawl).to receive(:new).and_return(crawl_mock)
        expect(crawl_mock).to receive(:start!).once

        capture_output { cli.call(arguments: ['crawl', crawl_config]) }
      end

      context 'when a wrong elasticsearch config is provided' do
        it 'shows an error message' do
          es_config = 'spec/fixtures/non-existent-es.yml'
          output = capture_output { cli.call(arguments: ['crawl', crawl_config, '--es-config', es_config]) }
          expect(output).to include("ERROR: Config file #{es_config} does not exist!")
        end
      end

      context 'when an elasticsearch config is provided' do
        it 'runs a crawl' do
          es_config_path = 'spec/fixtures/elasticsearch.yml'
          allow(Crawler::API::Crawl).to receive(:new).and_return(crawl_mock)
          expect(crawl_mock).to receive(:start!).once

          capture_output { cli.call(arguments: ['crawl', crawl_config, '--es-config', es_config_path]) }
        end

        it 'is superseded by crawl.yml' do
          es_config_path = 'spec/fixtures/elasticsearch.yml'
          expect(Crawler::API::Config).to receive(:new).with(
            hash_including({ elasticsearch: { password: 'changeme' } })
          ).once

          capture_output { cli.call(arguments: ['crawl', crawl_config, '--es-config', es_config_path]) }
        end
      end
    end

    it 'shows help page' do
      output = capture_output { cli.call(arguments: ['crawl', '-h']) }
      expected_output = <<~OUTPUT
        Command:
          #{cmd} crawl

        Usage:
          #{cmd} crawl CRAWL_CONFIG

        Description:
          Run a crawl of the site

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
