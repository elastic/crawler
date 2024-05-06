#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe 'Redirect handling' do
  let(:results) do
    num_redirects = 20
    FauxCrawl.crawl_site do
      page '/' do
        body do
          link_to '/simple-redirect'
          link_to '/circular-redirect'
          link_to '/infinite-redirect'
          link_to '/redirect-0'
        end
      end

      # Should not be indexed because it is a redirect
      page '/simple-redirect' do
        redirect '/hello'
      end

      # Should be discovered via the /simple-redirect page
      page '/hello'

      # Should not be indexed because it causes an circular redirect
      page '/circular-redirect' do
        redirect '/circular-redirect'
      end

      # Should not be indexed because it causes an infinite redirect
      page '/infinite-redirect' do
        redirect '/infinite-redirect-step2'
      end

      page '/infinite-redirect-step2' do
        redirect '/infinite-redirect'
      end

      # Create a chain of redirects that are longer than max_redirects
      num_redirects.times do |i|
        page "/redirect-#{i}" do
          redirect "/redirect-#{i + 1}"
        end
      end

      # Should not be indexed since it is referenced via a redirect chain that is too long
      page "/redirect-#{num_redirects}"
    end
  end

  it 'crawls all pages following redirects as needed' do
    expect(results).to have_only_these_results [
      # Home page
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),

      # First redirect chain: followed a redirect and indexed a page
      mock_response(url: 'http://127.0.0.1:9393/simple-redirect', status_code: 302,
                    location: 'http://127.0.0.1:9393/hello', redirect_count: 1),
      mock_response(url: 'http://127.0.0.1:9393/hello', status_code: 200),

      # Second redirect chain (single self-redirect, not followed because we have already seen the link)
      mock_response(url: 'http://127.0.0.1:9393/circular-redirect', status_code: 302,
                    location: 'http://127.0.0.1:9393/circular-redirect', redirect_count: 1),

      # Third redirect chain (infinite redirect chain broken by de-duplication)
      mock_response(url: 'http://127.0.0.1:9393/infinite-redirect', status_code: 302,
                    location: 'http://127.0.0.1:9393/infinite-redirect-step2', redirect_count: 1),
      mock_response(url: 'http://127.0.0.1:9393/infinite-redirect-step2', status_code: 302,
                    location: 'http://127.0.0.1:9393/infinite-redirect', redirect_count: 2),

      # Final (way too long) redirect chain
      mock_response(url: 'http://127.0.0.1:9393/redirect-0', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-1', redirect_count: 1),
      mock_response(url: 'http://127.0.0.1:9393/redirect-1', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-2', redirect_count: 2),
      mock_response(url: 'http://127.0.0.1:9393/redirect-2', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-3', redirect_count: 3),
      mock_response(url: 'http://127.0.0.1:9393/redirect-3', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-4', redirect_count: 4),
      mock_response(url: 'http://127.0.0.1:9393/redirect-4', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-5', redirect_count: 5),
      mock_response(url: 'http://127.0.0.1:9393/redirect-5', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-6', redirect_count: 6),
      mock_response(url: 'http://127.0.0.1:9393/redirect-6', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-7', redirect_count: 7),
      mock_response(url: 'http://127.0.0.1:9393/redirect-7', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-8', redirect_count: 8),
      mock_response(url: 'http://127.0.0.1:9393/redirect-8', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-9', redirect_count: 9),
      mock_response(url: 'http://127.0.0.1:9393/redirect-9', status_code: 302,
                    location: 'http://127.0.0.1:9393/redirect-10', redirect_count: 10)
    ]
  end
end
