# Crawler Directives

Crawler directives are external features that the Open Crawler adheres to.
These typically require no change to the Open Crawler configuration; instead, they are set up directly on the webserver or webpage.

These techniques are similar to search engine optimization (SEO) techniques used for other web crawlers and robots.
For example, you can embed instructions for the web crawler within your HTML content.
You can also prevent the crawler from following links or indexing any content for certain webpages.
Use these tools to manage webpage discovery and content extraction.

**Discovery** concerns which webpages and files from crawled domains get indexed:

- [Canonical URL link tags](#canonical-url-link-tags)
- [Robots meta tags](#robots-meta-tags)
- [Nofollow links](#nofollow-links) 
- [`robots.txt` files](#robotstxt-files) 
- [Sitemaps](#sitemaps)

**Extraction** concerns how content is indexed and mapped to fields in Elasticsearch documents:

- [Data attributes for inclusion and exclusion](#data-attributes-for-inclusion-and-exclusion) 

## HTML elements and attributes

The following sections describe crawler instructions you can embed within HTML elements and attributes.

### Canonical URL link tags

A canonical URL link tag is an HTML element you can embed within pages that duplicate the content of other pages.
The canonical URL link tag specifies the canonical URL for that content.

The canonical URL is stored on the document in the `url` field, while the `additional_urls` field contains all other URLs where the crawler discovered the same content.
If your site contains pages that duplicate the content of other pages, use canonical URL link tags to explicitly manage which URL is stored in the `url` field of the indexed document.

#### Template

```html
<link rel="canonical" href="{CANONICAL_URL}">
```

#### Example

```html
<link rel="canonical" href="https://example.com/categories/dresses/starlet-red-medium">
```

### Robots meta tags

Robots meta tags are HTML elements you can embed within pages to prevent the crawler from following links or indexing content.
These tags are related to [crawl rules](./CRAWL_RULES.md).

#### Template

```html
<meta name="robots" content="{DIRECTIVES}">
```

#### Supported directives

`noindex`

- The web crawler will not index the page
- If you want to index some, but not all, content on a page, see [data attributes for inclusion and exclusion](#data-attributes-for-inclusion-and-exclusion)

`nofollow`

- The web crawler will not follow links from the page
- The directive does not prevent the web crawler from indexing the page

#### Examples

```html
<meta name="robots" content="noindex">
<meta name="robots" content="nofollow">
<meta name="robots" content="noindex, nofollow">
```

### Data attributes for inclusion and exclusion

Inject HTML data attributes into your webpages to instruct the web crawler to include or exclude particular sections from extracted content.
For example, use this feature to exclude navigation and footer content when crawling, or to exclude sections of content only intended for screen readers.

These attributes work as follows:

- For all pages that contain HTML tags with a `data-elastic-include` attribute, the crawler will only index content within those tags.
- For all pages that contain HTML tags with a `data-elastic-exclude` attribute, the crawler will skip those tags from content extraction.
  - You can nest `data-elastic-include` and `data-elastic-exclude` tags.
- The web crawler will still crawl any links that appear inside excluded sections, as long as the configured crawl rules allow them.

#### Examples

Here's a simple content exclusion rule example:

```html
<body>
  <p>This is your page content, which will be indexed by the web crawler.
  <div data-elastic-exclude>Content in this div will be excluded from the search index</div>
</body>
```

In this more complex example with nested exclusion and inclusion rules, the web crawler will only extract "test1 test3 test5 test7" from the page.

```html
<body>
  test1
  <div data-elastic-exclude>
    test2
    <p data-elastic-include>
      test3
      <span data-elastic-exclude>
        test4
        <span data-elastic-include>test5</span>
      </span>
    </p>
    test6
  </div>
  test7
</body>
```

### Nofollow links

Nofollow links are HTML links that instruct the crawler to not follow the URL.

The web crawler will not follow links that include `rel="nofollow"` (that is, will not add links to the crawl queue).
The link does not prevent the web crawler from indexing the page in which it appears.

#### Template

```html
<a rel="nofollow" href="{LINK_URL}">{LINK_TEXT}</a>
```

#### Example

```html
<a rel="nofollow" href="/admin/categories">Edit this category</a>
```

## Server-based configurations

The following sections describe crawler instructions you can include on your webserver.

### `robots.txt` files

> [!TIP]
It is impossible to configure the web crawler to ignore or work around a domain’s `robots.txt` file.
Remember this if you’re crawling a domain you don’t control.

A domain may have a `robots.txt` file.
This is a plain text file that provides instructions to web crawlers.
The instructions within the file, also called directives, communicate which paths within that domain are disallowed (and allowed) for crawling.

You can also use a `robots.txt` file to specify [sitemaps](#sitemaps) for a domain.

Most web crawlers automatically fetch and parse the `robots.txt` file for each domain they crawl.
If you already publish a `robots.txt` file for other web crawlers, be aware the web crawler will fetch this file and honor the directives within it.
You may want to add, remove, or update the `robots.txt` file for each of your domains.

#### Example

To add a `robots.txt` file to the domain `https://shop.example.com`:

1. Determine which paths within the domain you’d like to exclude. 
2. Create a `robots.txt` file with the appropriate directives from the [robots exclusion standard](https://en.wikipedia.org/wiki/Robots_exclusion_standard), for example:
    ```txt
    User-agent: *
    Disallow: /cart
    Disallow: /login
    Disallow: /account
    ```
3. Publish the file, with filename `robots.txt`, at the root of the domain: `https://shop.example.com/robots.txt`.

The next time the web crawler visits the domain, it will fetch and parse the `robots.txt` file.
The web crawler will crawl only those paths that are allowed by the [crawl rules](./CRAWL_RULES.md) and the directives within the `robots.txt` file for the domain.

#### Nonstandard extensions

The Elastic web crawler supports some, but not all, [nonstandard extensions](https://en.wikipedia.org/wiki/Robots.txt#Nonstandard_extensions) to the robots exclusion standard:

| Directive             | Support       |
|-----------------------|---------------|
| Crawl-delay directive | Not supported | 
| Sitemap directive     | Supported     | 
| Host directive        | Not supported | 

### Sitemaps

A sitemap is an XML file, associated with a domain, that informs web crawlers about pages within that domain.
XML elements within the sitemap identify specific URLs that are available for crawling.
Each domain may have one or more sitemaps.

If you already publish sitemaps for other web crawlers, the web crawler can use the same sitemaps.
To make your sitemaps discoverable, specify them within `robots.txt` files.

Sitemaps are related to the `seed_urls` configuration field.
You can choose to submit URLs to the web crawler using sitemaps, seed URLs, or a combination of both.

Use sitemaps to inform the web crawler of pages you think are important, or pages that are isolated and not linked from other pages.
However, be aware the web crawler will visit only those pages from the sitemap that are allowed by the domain’s [crawl rules](./CRAWL_RULES.md) and [robots.txt](#robotstxt-files) file directives.

#### Sitemap discovery and management

To add a sitemap to a domain, you can specify it within a `robots.txt` file.
At the start of each crawl, the web crawler fetches and processes each domain’s `robots.txt` file and each sitemap specified within those `robots.txt` files.

#### Sitemap format and technical specification

The [sitemaps standard](https://www.sitemaps.org/index.html) defines the format and technical specification for sitemaps.
Refer to the standard for the required and optional elements, character escaping, and other technical considerations and examples.

The web crawler does not process optional metadata defined by the standard.
The web crawler extracts a list of URLs from each sitemap and ignores all other information.

There is no guarantee that pages (and their respective linked pages) will be indexed in the order they appear in the sitemap, because crawls are run asynchronously.

Ensure each URL within your sitemap matches the exact domain — here defined as scheme + host + port— for your site.
Different subdomains (like `www.example.com` and `blog.example.com`) and different schemes (like `http://example.com` and `https://example.com`) require separate sitemaps.

The web crawler also supports sitemap index files.
Refer to [using sitemap index files](https://www.sitemaps.org/protocol.html#index) within the sitemap standard for sitemap index file details and examples.

#### Manage sitemaps

To add a sitemap to the domain `https://shop.example.com`:

1. Determine which pages within the domain you’d like to include
   - Ensure these paths are allowed by the domain’s crawl rules and the directives within the domain’s `robots.txt` file
2. Create a sitemap file with the appropriate elements from the sitemap standard, for example:
    ```xml
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc>https://shop.example.com/products/1/</loc>
      </url>
      <url>
        <loc>https://shop.example.com/products/2/</loc>
      </url>
      <url>
        <loc>https://shop.example.com/products/3/</loc>
      </url>
    </urlset>
    ```
3. Publish the file on your site, for example, at the root of the domain: `https://shop.example.com/sitemap.xml`.
4. Create or modify the `robots.txt` file for the domain, located at `https://shop.example.com/robots.txt`
   - Anywhere within the file, add a Sitemap directive that provides the location of the sitemap. For instance:
       ```txt
       Sitemap: https://shop.example.com/sitemap.xml
       ```
5. Publish the new or updated `robots.txt` file.

The next time the web crawler visits the domain, it will fetch and parse the `robots.txt` file and the sitemap.
