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

    context 'when a crawle config is provided' do
      let(:crawl_config) { 'spec/fixtures/crawl.yml' }

      context 'when validation is successful' do
        it 'displays that the domain is validated' do
          allow(Crawler::UrlValidator).to receive(:new).and_return(double(valid?: true))
          output = capture_output { cli.call(arguments: ['validate', crawl_config]) }
          expect(output).to include('is valid')
        end
      end

      context 'when validation is not successful' do
        it 'displays that the domain is not validated' do
          allow(Crawler::UrlValidator).to receive(:new).and_return(double(valid?: false, failed_checks: [double(comment: 'error')]))
          output = capture_output { cli.call(arguments: ['validate', crawl_config]) }
          expect(output).to include('is invalid:')
          expect(output).to include('error')
        end
      end
    end

    it 'shows help page' do
      output = capture_output { cli.call(arguments: ['validate', '-h']) }
      expected_output = <<~OUTPUT
        Command:
          #{cmd} validate

        Usage:
          #{cmd} validate CRAWL_CONFIG

        Description:
          Validate crawler configuration

        Arguments:
          CRAWL_CONFIG                      # REQUIRED Path to crawl config file

        Options:
          --help, -h                        # Print this help
      OUTPUT

      expect(output).to eq(expected_output)
    end
  end
end
