#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::Data::Link) do
  let(:base) { 'https://example.org' }
  let(:base_url) { Crawler::Data::URL.parse(base) }

  let(:broken_link_string) { 'foo%:' }
  let(:broken_link) { Crawler::Data::Link.new(base_url: base_url, link: broken_link_string) }

  let(:valid_link_string) { '/foo' }
  let(:valid_link) { Crawler::Data::Link.new(base_url: base_url, link: valid_link_string) }

  let(:xml_link) { Nokogiri::HTML.parse('<a href="http://google.com">').css('a').first }

  #-------------------------------------------------------------------------------------------------
  describe 'constructor' do
    it 'should require either an html or a string link' do
      expect { Crawler::Data::Link.new(base_url: base_url) }.to raise_error(ArgumentError)
    end

    it 'should fail if given a non-string link argument' do
      expect { Crawler::Data::Link.new(base_url: base_url, link: 123) }.to raise_error(ArgumentError)
    end

    it 'should fail if given a non-XML node argument' do
      expect { Crawler::Data::Link.new(base_url: base_url, node: 'boo') }.to raise_error(ArgumentError)
    end

    it 'should not fail if the link is invalid' do
      expect { broken_link }.to_not raise_error
    end

    it 'should fail when given both an XML and a string link argument' do
      expect do
        Crawler::Data::Link.new(
          base_url: base_url,
          node: xml_link,
          link: valid_link_string
        )
      end.to raise_error(ArgumentError)
    end

    it 'should initialize the link value using a href attribute when given an HTML link' do
      link = Crawler::Data::Link.new(base_url: base_url, node: xml_link)
      expect(link.link).to eq(xml_link['href'])
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe 'comparison operators' do
    context 'when initialized with a link' do
      let(:link1) { Crawler::Data::Link.new(base_url: base_url, link: valid_link_string) }
      let(:link2) { Crawler::Data::Link.new(base_url: base_url, link: valid_link_string) }

      it 'should work with a Set' do
        set = Set.new([link1, link2])
        expect(set.count).to eq(1)
      end

      it 'should consider both links equal' do
        expect(link1).to eq(link2)
      end

      it 'should consider links different if the link value differs' do
        another_link = Crawler::Data::Link.new(base_url: base_url, link: '/yo')
        expect(link1).to_not eq(another_link)
      end

      it 'should consider links different if the base URL value differs' do
        another_base = Crawler::Data::URL.parse('https://kovyrin.net')
        another_link = Crawler::Data::Link.new(base_url: another_base, link: valid_link_string)
        expect(link1).to_not eq(another_link)
      end
    end

    context 'when initialized with an HTML link' do
      let(:link1) { Crawler::Data::Link.new(base_url: base_url, node: xml_link) }
      let(:link2) { Crawler::Data::Link.new(base_url: base_url, node: xml_link) }

      it 'should work with a Set' do
        set = Set.new([link1, link2])
        expect(set.count).to eq(1)
      end

      it 'should consider both links equal' do
        expect(link1).to eq(link2)
      end

      it 'should consider links different if the html link value differs' do
        another_xml_link = Nokogiri::HTML.parse('<a href="http://amazon.com">').css('a').first
        another_link = Crawler::Data::Link.new(base_url: base_url, node: another_xml_link)
        expect(link1).to_not eq(another_link)
      end

      it 'should consider links equal even when they come from different tags' do
        html = Nokogiri::HTML.parse('<a href="http://google.com"><a href="http://google.com">')
        links = html.css('a')
        link1 = Crawler::Data::Link.new(base_url: base_url, node: links[0])
        link2 = Crawler::Data::Link.new(base_url: base_url, node: links[1])
        expect(link1).to eq(link2)
      end

      it 'should consider links different if they have different HTML attributes' do
        nofollow_link = Nokogiri::HTML.parse('<a href="http://google.com" rel="nofollow">').css('a').first
        another_link = Crawler::Data::Link.new(base_url: base_url, node: nofollow_link)
        expect(link1).to_not eq(another_link)
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#valid?' do
    it 'should return false for a broken link' do
      expect(broken_link).to_not be_valid
    end

    it 'should return false for a link without href' do
      node_html = '<a :href="url" class="Product__details  t-small" v-cloak="" v-if="bundle">View product details</a>'
      node = Nokogiri::HTML.parse(node_html).css('a').first
      link = Crawler::Data::Link.new(base_url: base_url, node: node)
      expect(link).to_not be_valid
      expect(link.error).to eq("Link has no href attribute: #{node_html}")
    end

    it 'should return true for a valid link' do
      expect(valid_link).to be_valid
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#to_url' do
    it 'should raise an error for a broken link' do
      expect { broken_link.to_url }.to raise_error(Addressable::URI::InvalidURIError)
    end

    it 'should return an absolute URL for a valid link' do
      url = valid_link.to_url
      expect(url).to be_a(Crawler::Data::URL)
      expect(url.to_s).to eq(base + valid_link_string)
    end
  end

  #-------------------------------------------------------------------------------------------------
  describe '#error' do
    it 'should return an error for a broken link' do
      expect(broken_link.error).to match(/Invalid/)
    end

    it 'should return nil for a valid link' do
      expect(valid_link.error).to be_nil
    end
  end
end
