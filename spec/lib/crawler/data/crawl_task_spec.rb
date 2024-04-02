# frozen_string_literal: true

RSpec.describe Crawler::Data::CrawlTask do
  let(:url) { Crawler::Data::URL.parse('https://example.com/') }
  let(:task) { Crawler::Data::CrawlTask.new(:url => url, :type => :content, :depth => 1) }

  describe '#inspect' do
    it 'should return a nice representation of the object for logging' do
      expect(task.inspect).to be_a(String)
      expect(task.inspect).to match(/CrawlTask/)
    end
  end
end
