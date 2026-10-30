#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'tmpdir'

RSpec.describe(Crawler::CLI::Agent) do
  describe '.call' do
    let(:cli) { Dry::CLI(Crawler::CLI) }
    let(:cmd) { File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME)) }
    let(:component) { instance_double(Crawler::Agent::Component, run: nil) }

    it 'runs the agent component with the default check-in interval' do
      expect(Crawler::Agent::Component).to receive(:new).with(checkin_interval: 5).and_return(component)
      cli.call(arguments: ['agent'])
    end

    it 'accepts a custom check-in interval' do
      expect(Crawler::Agent::Component).to receive(:new).with(checkin_interval: 10).and_return(component)
      cli.call(arguments: ['agent', '--checkin-interval=10'])
    end

    it 'accepts Elastic Agent setting overrides and switches to the data directory' do
      expect(Crawler::Agent::Component).to receive(:new).and_return(component)
      data_dir = Dir.mktmpdir
      original = Dir.pwd
      begin
        arguments = Crawler::CLI.normalize_agent_arguments(['agent', '-E', "path.data=#{data_dir}/run", '-E',
                                                            'other=1'])
        expect(arguments).to eq(['agent', "--data-dir=#{data_dir}/run"])
        cli.call(arguments:)
        expect(File.realpath(Dir.pwd)).to eq(File.realpath("#{data_dir}/run"))
      ensure
        Dir.chdir(original)
      end
    end

    it 'leaves other commands untouched' do
      expect(Crawler::CLI.normalize_agent_arguments(['crawl', '-E', 'x'])).to eq(['crawl', '-E', 'x'])
    end

    it 'prints an error and exits when the component fails' do
      allow(Crawler::Agent::Component).to receive(:new).and_return(component)
      allow(component).to receive(:run).and_raise(Crawler::Agent::Error, 'no agent')
      output = capture_output { cli.call(arguments: ['agent']) }
      expect(output).to include('ERROR: Crawler::Agent::Error: no agent')
    end

    it 'shows help page' do
      output = capture_output { cli.call(arguments: ['agent', '-h']) }
      expect(output).to include("#{cmd} agent")
      expect(output).to include('Run the crawler as an Elastic Agent component')
      expect(output).to include('--checkin-interval')
    end
  end
end
