#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::CrawlResult::HTML) do
  let(:url) { Crawler::Data::URL.parse('https://example.com/') }

  let(:crawl_result) do
    described_class.new(
      url: url,
      content: html
    )
  end

  let(:html) do
    <<~HTML
      <html>
      <head>
        <title>Under construction...</title>
        <link rel="canonical" href="https://example.com/canonical" />
        <meta name="keywords" content="keywords, stuffing, SEO" />
        <meta name="description" content="The best site in the universe!" />
      </head>
      <body>
        <h1>Page header</h1>
        Something
        something   else
        <div data-elastic-exclude>
        <a href="https://google.com">google</a>
        </div>

        <!-- should remove this whole tag -->
        <script>alert("hello from Javascript")</script>

        <!-- should remove this whole tag -->
        <svg height="130" width="500">
          <defs>
            <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" style="stop-color:rgb(255,255,0);stop-opacity:1" />
              <stop offset="100%" style="stop-color:rgb(255,0,0);stop-opacity:1" />
            </linearGradient>
          </defs>
          <ellipse cx="100" cy="70" rx="85" ry="55" fill="url(#grad1)" />
          <text fill="#ffffff" font-size="45" font-family="Verdana" x="50" y="86">SVG</text>
          Sorry, your browser does not support inline SVG.
        </svg>

        <h2>Links section</h2>

        <!-- Should not insert a space between the words extracted from these links -->
        <a class="linkedin" href="https://www.linkedin.com/company/swiftype">LinkedIn</a><span>or</span><a class="instagram" href="https://www.instagram.com/swiftype.search">Instagram</a>

        <!-- Should insert a space between the words extracted from these list items -->
        <li><a class="twitter" href="https://twitter.com/swiftype">Twitter</a><li><a class="facebook" href="https://facebook.com/swiftype">Facebook</a>

        <!-- Should strip leading and trailing whitespace from href -->
        <a href=" https://swiftype.com/site-search ">Swiftype</a>

        <!-- Should skip links without a proper href attribute -->
        <a :href="url" class="Product__details  t-small" v-cloak="" v-if="bundle">
          View product details
        </a>
      <body></html>
    HTML
  end

  #-------------------------------------------------------------------------------------------------
  describe '#content' do
    it 'should return the content' do
      expect(crawl_result.content).to be_a(String)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#base_url' do
    context 'when a <base> tag is present with a href attribute' do
      let(:html) { read_fixture('gilacountyaz.gov.html') }

      it 'should use the <base> href value' do
        base_link = Crawler::Data::URL.parse('https://www.gilacountyaz.gov/index.php')
        expect(crawl_result.base_url).to eq(base_link)
      end

      context 'with spaces around the link' do
        let(:html) { '<html><head><base href="  https://example.com/hello  "></head></html>' }

        it 'should strip the spaces' do
          base_link = Crawler::Data::URL.parse('https://example.com/hello')
          expect(crawl_result.base_url).to eq(base_link)
        end
      end

      context 'when the link is invalid' do
        let(:html) { '<html><head><base href="%https:/"></head></html>' }

        it 'should ignore the error and use the page URL' do
          expect(crawl_result.base_url).to eq(crawl_result.url)
        end
      end
    end

    context 'when a <base> tag is present, but without a href attribute' do
      let(:html) { '<html><head><base target="_blank"></head></html>' }

      it 'should use the page URL' do
        expect(crawl_result.base_url).to eq(crawl_result.url)
      end
    end

    context 'when a <base> tag is present, but the href value is empty' do
      let(:html) { '<html><head><base href=""></head></html>' }

      it 'should use the page URL' do
        expect(crawl_result.base_url).to eq(crawl_result.url)
      end
    end

    context 'when a <base> tag is present, and it is a relative URL' do
      let(:relative_base_url) { '/hello' }
      let(:html) { "<html><head><base href='#{relative_base_url}'></head></html>" }

      it 'should use crawl URL as start for the relative URL' do
        expect(crawl_result.base_url).to eq(crawl_result.url + relative_base_url)
      end
    end

    context 'with multiple base tags' do
      let(:html) do
        <<~HTML
          <html>
            <head>
              <base target="_blank">
              <base href="https://example.com/hello">
              <base href="https://example.com/world">
            </head>
          </html>
        HTML
      end

      it 'should use the first href value' do
        base_link = Crawler::Data::URL.parse('https://example.com/hello')
        expect(crawl_result.base_url).to eq(base_link)
      end
    end

    it 'should use the page URL if no <base> tag is present' do
      expect(crawl_result.base_url).to eq(crawl_result.url)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#extract_links' do
    let(:links) { crawl_result.extract_links.fetch(:links) }

    it 'should return a set of links from the document' do
      expect(links).to be_kind_of(Set)
      expect(links.count).to eq(7)
      expect(links.count(&:valid?)).to eq(6)
      expect(links).to all(be_kind_of(Crawler::Data::Link))
    end

    it 'should support limiting the number of links extracted' do
      links, limit_reached = crawl_result.extract_links(limit: 2).values_at(:links, :limit_reached)
      expect(links).to be_kind_of(Set)
      expect(links.count).to eq(2)
      expect(limit_reached).to be(true)
    end

    context 'robots: nofollow' do
      let(:html) do
        <<~HTML
          <html>
          <head>
            <title>Under construction...</title>
            <meta name="robots" content="nofollow" />
          </head>
          <body>
            <a href="https://google.com">google</a>
            <a href="https://swiftype.com/site-search">Swiftype</a>
            <a class="linkedin" href="https://www.linkedin.com/company/swiftype">LinkedIn</a>
            <a class="instagram" href="https://www.instagram.com/swiftype.search">Instagram</a>
          <body>
          </html>
        HTML
      end

      it 'should return a set of links as usual' do
        expect(links).to be_kind_of(Set)
        expect(links.count).to eq(4)
      end
    end

    context 'links with rel=nofollow' do
      let(:html) do
        <<~HTML
          <html>
          <head>
            <title>Under construction...</title>
          </head>
          <body>
            <a href="https://google.com">google</a>
            <a class="linkedin" href="https://www.linkedin.com/company/swiftype">LinkedIn</a>
            <a rel="nofollow" href="https://swiftype.com/site-search">Check this site out!</a>
            <a class="instagram" href="https://www.instagram.com/swiftype.search">Instagram</a>
          <body>
          </html>
        HTML
      end

      it 'should return all links with nofollow attribute set appropriately' do
        expect(links).to be_kind_of(Set)
        links_by_nofollow = links.group_by(&:rel_nofollow?)

        expect(links_by_nofollow[false].map(&:to_url)).to contain_exactly(
          Crawler::Data::URL.parse('https://google.com'),
          Crawler::Data::URL.parse('https://www.linkedin.com/company/swiftype'),
          Crawler::Data::URL.parse('https://www.instagram.com/swiftype.search')
        )

        expect(links_by_nofollow[true].map(&:to_url)).to eq([Crawler::Data::URL.parse('https://swiftype.com/site-search')])
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#links' do
    it 'should return an ordered array of links from the page as strings' do
      res = crawl_result.links
      expect(res).to be_kind_of(Array)
      expect(res.count).to eq(6)
      expect(res.first).to be_kind_of(String)
      expect(res).to eq(res.sort)
    end

    it 'should limit the number of links down to a given value' do
      expect(crawl_result.links(limit: 5).count).to eq(5)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#canonical_url' do
    it 'should return the canonical url when possible' do
      expect(crawl_result.canonical_url.to_s).to eq('https://example.com/canonical')
    end

    context 'when canonical URL is a relative URL' do
      let(:html) { '<html><head><link rel="canonical" href="/canonical" /></head></html>' }
      it 'should return the canonical url with a FQDN' do
        expect(crawl_result.canonical_url.to_s).to eq('https://example.com/canonical')
      end
    end

    context 'when there is no head tag' do
      let(:html) { '<html><body>Headless page</body></html>' }
      it 'should return the nil' do
        expect(crawl_result.canonical_url).to be_nil
      end
    end

    context 'when where is no head or any other title tag' do
      let(:html) { '' }
      it 'should return an empty string' do
        expect(crawl_result.canonical_url).to be_nil
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#document_title' do
    it 'should return the <head> <title> contents when possible' do
      expect(crawl_result.document_title).to eq('Under construction...')
    end

    context 'when there is no head title tag, but where is a <title> tag somewhere on the page' do
      let(:html) { '<html><body><title>HTML5, yo!</title></body>' }

      it 'should return the first <title> tag' do
        expect(crawl_result.document_title).to eq('HTML5, yo!')
      end
    end

    context 'when where is no head or any other title tag' do
      let(:html) { '' }

      it 'should return an empty string' do
        expect(crawl_result.document_title).to eq('')
      end
    end

    it 'should truncate the value to a given length' do
      expect(crawl_result.document_title(limit: 10).bytesize).to eq(10)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#document_body' do
    let(:body_text) { crawl_result.document_body }

    context 'when presented with an empty page' do
      let(:html) { '' }

      it 'should return an empty string' do
        expect(body_text).to eq('')
      end
    end

    it 'should remove empty spaces from the content' do
      expect(body_text).to match('Something something else')
    end

    it 'should remove tags from the content' do
      expect(body_text).to_not match('</a>')
    end

    it 'should remove script tags along with the content' do
      expect(body_text).to_not match('alert')
    end

    it 'should remove svg tags along with all of their children' do
      expect(body_text).to_not match(/svg/i)
    end

    it 'should replace tags with spaces when needed' do
      expect(body_text).to match('Twitter Facebook')
    end

    it 'should wrap inline elements with spaces' do
      expect(body_text).to match('LinkedIn or Instagram')
    end

    it 'should remove HTML comments' do
      expect(body_text).to_not match('should remove this whole tag')
    end

    it 'should truncate the value to a given length' do
      expect(crawl_result.document_body(limit: 10).bytesize).to eq(10)
    end

    it 'should remove elements with data-elastic-exclude' do
      expect(body_text).to_not match(/google/i)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#meta_keywords' do
    it 'should return keywords' do
      expect(crawl_result.meta_keywords).to eq('keywords, stuffing, SEO')
    end

    it 'should truncate the value to a given length' do
      expect(crawl_result.meta_keywords(limit: 10).bytesize).to eq(10)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#meta_description' do
    it 'should return keywords' do
      expect(crawl_result.meta_description).to eq('The best site in the universe!')
    end

    it 'should truncate the value to a given length' do
      expect(crawl_result.meta_description(limit: 10).bytesize).to eq(10)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#headings' do
    let(:headings) { crawl_result.headings }

    it 'should return an array of headings' do
      expect(headings).to eq ['Page header', 'Links section']
    end

    it 'should cap the results based on the given limit' do
      expect(crawl_result.headings(limit: 1)).to eq ['Page header']
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#extract_by_selector' do
    let(:selector) { nil }
    subject { crawl_result.extract_by_selector(selector, []) }

    context 'when selector finds single HTML node' do
      let(:selector) { 'title' }

      it { is_expected.to eq(['Under construction...']) }
    end

    context 'when selector finds multiple HTML nodes' do
      let(:selector) { 'body a' }

      it {
        is_expected.to eq(['google', 'LinkedIn', 'Instagram', 'Twitter', 'Facebook', 'Swiftype',
                           'View product details'])
      }
    end

    context 'when selector does not find any HTML nodes' do
      let(:selector) { 'incorrect selector' }

      it { is_expected.to be_kind_of(Array) }
      it { is_expected.to be_empty }
    end

    context 'when selector is an XPath expression' do
      let(:selector) { '//a/text()' }

      it { is_expected.to be_kind_of(Array) }
      it {
        is_expected.to eq(['google', 'LinkedIn', 'Instagram', 'Twitter', 'Facebook', 'Swiftype',
                           'View product details'])
      }
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#full_html' do
    it 'should return nil if enabled is false' do
      expect(crawl_result.full_html).to be_nil
      expect(crawl_result.full_html(enabled: false)).to be_nil
    end

    it 'should return the full HTML as a string if enabled is true' do
      full_html = crawl_result.full_html(enabled: true)
      expect(full_html).to be_a(String)
      expect(full_html).to eq(Nokogiri::HTML.parse(html).inner_html)
      expect(full_html).to match(/script/)
      expect(full_html).to match(/svg/)
    end
  end
end
