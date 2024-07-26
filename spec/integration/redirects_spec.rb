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
    # The following redirect chains don't show up in results:
    #
    # circular-redirect (single self-redirect, not followed because we have already seen the link)
    # infinite-redirect (infinite redirect chain broken by de-duplication)
    # redirect-(n) (way too many redirects)
    expect(results).to have_only_these_results [
      # Home page (no redirects)
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),

      # First redirect chain: followed a redirect and indexed a page
      mock_response(url: 'http://127.0.0.1:9393/hello', status_code: 200),
    ]
  end
end
