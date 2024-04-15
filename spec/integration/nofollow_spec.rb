# frozen_string_literal: true

RSpec.describe 'Robots meta support' do
  let(:results) do
    FauxCrawl.crawl_site do
      page '/' do
        body do
          link_to '/noindex'
          link_to '/nofollow'

          # This link will not be followed
          link_to '/unreachable', rel: :nofollow
        end
      end

      # Should not be indexed, but the links should be followed
      page '/noindex' do
        head { robots 'noindex' }
        body { link_to '/foo' }
      end

      # Should be indexed, but the links should not be followed
      page '/nofollow' do
        head { robots 'nofollow' }
        body { link_to '/unreachable' }
      end

      # Only reachable via /noindex
      page '/foo'

      # Only reachable via nofollow links and pages, so the crawler won't ever find this
      page '/unreachable'
    end
  end

  it 'crawls all pages given the constraints specified by robots meta tags' do
    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/nofollow', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/foo', status_code: 200)
    ]
  end
end
