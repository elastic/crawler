# frozen_string_literal: true

RSpec.describe 'Crawler Environment' do
  it 'should have CRAWLER_ENV defined' do
    expect(defined?(CRAWLER_ENV)).to eq('constant')
  end
end
