#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::CLI::UrlTest) do
  describe '.call' do
    let(:cli) { Dry::CLI(Crawler::CLI) }

    let(:cmd) { File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME)) }

    let(:endpoint) { 'https://example.com/website' }

    context 'when crawl config is not provided' do
      it 'shows an error message' do
        output = capture_error { cli.call(arguments: ['urltest']) }
        expect(output).to include("ERROR: \"#{cmd} urltest\" was called with no arguments")
        expect(output).to include("Usage: \"#{cmd} urltest CRAWL_CONFIG ENDPOINT\"")
      end
    end

    context 'when a wrong crawl config is provided' do
      let(:crawl_config) { 'spec/fixtures/non-existent-crawl.yml' }
      it 'shows an error message' do
        output = capture_output { cli.call(arguments: ['urltest', crawl_config, endpoint]) }
        expect(output).to include("ERROR: Config file #{crawl_config} does not exist!")
      end
    end

    context 'when a crawler config and endpoint is provided' do
      let(:crawl_config) { 'spec/fixtures/crawl.yml' }
      let(:crawl_mock) { double }

      before(:example) do
        allow(crawl_mock).to receive(:start_url_test!).and_return(true)
      end

      it 'runs a url test crawl' do
        allow(Crawler::API::Crawl).to receive(:new).and_return(crawl_mock)
        expect(crawl_mock).to receive(:start_url_test!).once

        capture_output { cli.call(arguments: ['urltest', crawl_config, endpoint]) }
      end

      context 'when a wrong elasticsearch config is provided' do
        it 'shows an error message' do
          es_config = 'spec/fixtures/non-existent-es.yml'
          output = capture_output { cli.call(arguments: ['urltest', crawl_config, endpoint, '--es-config', es_config]) }
          expect(output).to include("ERROR: Config file #{es_config} does not exist!")
        end
      end

      context 'when an elasticsearch config is provided' do
        let(:crawl_config_mock) { double }
        it 'runs a crawl' do
          es_config_path = 'spec/fixtures/elasticsearch.yml'
          allow(Crawler::API::Crawl).to receive(:new).and_return(crawl_mock)
          expect(crawl_mock).to receive(:start_url_test!).once

          capture_output { cli.call(arguments: ['urltest', crawl_config, endpoint, '--es-config', es_config_path]) }
        end
      end
    end
  end
end
