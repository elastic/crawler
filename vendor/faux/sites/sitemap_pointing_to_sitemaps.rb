#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#
class SitemapPointingToSitemaps < Faux::Base
  robots do
    user_agent '*'

    sitemap '/sitemap.xml'
  end

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
