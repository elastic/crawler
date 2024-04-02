# frozen_string_literal: true

RSpec.describe 'Seed URLs' do
  let(:site) do
    Faux.site do
      page '/foo'
      page '/baz'
    end
  end

  it 'crawls all of the seed urls specified by the config' do
    results = FauxCrawl.run(site, :seed_urls => ['/foo', '/baz'])

    expect(results).to have_only_these_results [
      mock_response(:url => 'http://127.0.0.1:9393/foo', :status_code => 200),
      mock_response(:url => 'http://127.0.0.1:9393/baz', :status_code => 200)
    ]
  end
end
