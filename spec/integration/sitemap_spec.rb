#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe 'Sitemaps Support' do
  let(:site) do
    Faux.site do
      page '/' do
        body do
          link_to '/foo'
        end
      end

      # Could be discovered via the home page or the sitemap
      page '/foo'

      # Not linked directly, but discoverable via the sitemap
      page '/bar' do
        body do
          link_to '/baz'
        end
      end

      # Not linked directly, but discoverable via '/bar'
      page '/baz'

      sitemap '/sitemap.xml' do
        link_to '/'
        link_to '/foo'
        link_to '/bar'
      end
    end
  end

  it 'makes it possible to use sitemap seed URLs for discovering links on a site' do
    results = FauxCrawl.run(
      site,
      seed_urls: ['http://127.0.0.1:9393/'],
      sitemap_urls: ['http://127.0.0.1:9393/sitemap.xml']
    )

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/foo', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/bar', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/baz', status_code: 200)
    ]
  end
end
