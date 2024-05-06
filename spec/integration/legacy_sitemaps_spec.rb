#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe 'Sitemap specs from Swiftype.com' do
  let(:results) { FauxCrawl.run(site) }

  def site_with_sitemap(&block)
    Faux.site do
      robots do
        user_agent '*'
        sitemap '/sitemap.xml'
      end

      instance_eval(&block) if block
    end
  end

  #-------------------------------------------------------------------------------------------------
  context 'sitemap with links' do
    let(:site) do
      site_with_sitemap do
        sitemap '/sitemap.xml' do
          link_to '/bar'
        end

        page '/foo'
        page '/bar'
      end
    end

    it 'extracts links from sitemap' do
      expect(results).to have_only_these_results [
        mock_response(url: 'http://127.0.0.1:9393/', status_code: 404),
        mock_response(url: 'http://127.0.0.1:9393/bar', status_code: 200)
      ]
    end
  end

  #-------------------------------------------------------------------------------------------------
  context 'index of other sitemaps' do
    let(:site) do
      site_with_sitemap do
        sitemap_index '/sitemap.xml' do
          link_to '/sitemap_1.xml'
          link_to '/sitemap_2.xml'
        end

        sitemap '/sitemap_1.xml' do
          link_to '/foo'
        end

        sitemap '/sitemap_2.xml' do
          link_to '/bar'
        end

        page '/foo'
        page '/bar'
      end
    end

    it 'discovers links in the sitemap' do
      expect(results).to have_only_these_results [
        mock_response(url: 'http://127.0.0.1:9393/', status_code: 404),
        mock_response(url: 'http://127.0.0.1:9393/foo', status_code: 200),
        mock_response(url: 'http://127.0.0.1:9393/bar', status_code: 200)
      ]
    end
  end

  #-------------------------------------------------------------------------------------------------
  context 'with gzipped sitemap' do
    let(:site) do
      site_with_sitemap do
        sitemap_gz '/sitemap.xml' do
          link_to '/bar'
        end

        page '/'
        page '/bar'
      end
    end

    it 'extracts links from sitemap' do
      expect(results).to have_only_these_results [
        mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
        mock_response(url: 'http://127.0.0.1:9393/bar', status_code: 200)
      ]
    end
  end
end
