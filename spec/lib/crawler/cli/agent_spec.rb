#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

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
