# frozen_string_literal: true

RSpec.describe(Crawler) do
  it 'should define a version' do
    expect(Crawler.version).to be_a(String)
  end

  context '.service_id' do
    it 'should be cached' do
      expect(Crawler.service_id).to be(Crawler.service_id)
    end

    it 'should be process-scoped (not thread-local)' do
      id1 = Crawler.service_id

      t = Thread.new { Thread.current[:service_id] = Crawler.service_id }.join
      id2 = t[:service_id]
      expect(id1).to be(id2)
    end
  end
end
