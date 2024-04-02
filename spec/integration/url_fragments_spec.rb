# frozen_string_literal: true

RSpec.describe 'URL normalization in the presence of URL fragments' do
  let(:results) do
    FauxCrawl.crawl_site do
      page '/' do
        body do
          link_to '/foo'
          link_to '/foo#bar'
          link_to '/baz#hello'
        end
      end

      page '/foo'
      page '/baz'
    end
  end

  it 'crawls discovered URLs while stripping out the fragments' do
    expect(results).to have_only_these_results [
      mock_response(:url => 'http://127.0.0.1:9393/', :status_code => 200),
      mock_response(:url => 'http://127.0.0.1:9393/foo', :status_code => 200),
      mock_response(:url => 'http://127.0.0.1:9393/baz', :status_code => 200)
    ]
  end
end
