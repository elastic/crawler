class SimpleSite < Faux::Base
  page '/' do
    head { atom_to '/feed' }
    body { link_to '/foo' }
  end

  page '/foo' do
    status 200
    body { link_to '/foobar' }
  end

  path_with_content_length '/large_page', 10.megabytes

  atom_feed '/feed' do
    entry do
      title 'Another Post'
      link_to '/foo'
      link_to '/wow'
    end

    entry do
      link_to '/bar'
    end
  end

  page '/bar' do
    status 200
    body do
      link_to '/bang', :relative => false
      link_to '/baz'
    end
  end

  page '/redirect' do
    redirect '/foo'
  end

  sitemap '/sitemap.xml' do
    link_to '/foo'
    link_to '/bar'
  end

  robots do
    user_agent '*'
    disallow '/foo'

    # Sitemap urls should be absolute. Pass :relative => true
    # so the url will be converted from relative to absolute.
    sitemap '/sitemap.xml', :relative => true
  end
end
