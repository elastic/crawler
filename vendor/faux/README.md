# Faux

Faux is little Rack-based DSL for generating websites. Here's a simple example:

``` ruby
class SimpleSite < Faux::Base
  page '/foo' do
    status 200
    link_to '/foobar'
  end

  page '/bar' do
    status 200
    link_to '/bang'
    link_to '/baz'
  end

  sitemap '/sitemap.xml' do
    link_to 'http://localhost:9393/foo'
    link_to '/bar'
  end

  # Adds a /robots.txt file with the specified rules.
  robots do
    user_agent '*'
    disallow '/foo'
    sitemap 'http://localhost:9393/sitemap.xml'
  end
end
```

To boot the example site locally:
``` shell
  $ bundle exec rackup
```

The site will be running at `localhost:9393`

### Request Counter

After booting an app, visit `/status` for a JSON report of which URLs have been visited and how many times they've been visited while the app has been running. It'll look like this:

``` json
{
  "/bar": 7,
  "/foo": 5
}
```
