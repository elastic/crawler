#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::HttpUtils::Config) do
  describe 'constructor' do
    let(:valid_config) do
      {
        loopback_allowed: false,
        private_networks_allowed: false,
        logger: Logger.new($stdout)
      }
    end

    described_class::REQUIRED_OPTIONS.each do |opt|
      it "requires #{opt} option" do
        expect do
          described_class.new(valid_config.except(opt))
        end.to raise_error(ArgumentError, "#{opt} is a required option")
      end
    end
  end
end
