#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe 'Crawler Environment' do
  it 'should have CRAWLER_ENV defined' do
    expect(defined?(CRAWLER_ENV)).to eq('constant')
  end
end
