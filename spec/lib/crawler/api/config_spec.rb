#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::API::Config) do
  describe '#initialize' do
    let(:domain1) do
      {
        url: 'https://domain1.com',
        seed_urls: %w[https://domain1.com/forum https://domain1.com/wiki],
        sitemap_urls: %w[https://domain1.com/sitemap/foo.xml]
      }
    end
    let(:domain2) { { url: 'http://domain2.com' } }
    let(:domains) { [domain1, domain2] }

    # https on port 443, http on port 80
    let(:expected_allowlist) { %W[#{domain1[:url]}:443 #{domain2[:url]}:80] }
    let(:expected_seed_urls) { ["#{domain2[:url]}/"] + domain1[:seed_urls] }

    let(:output_dir) { '/tmp/crawler/example.com/123' }

    it 'should fail when provided with unknown options' do
      expect do
        Crawler::API::Config.new(fubar: 42)
      end.to raise_error(ArgumentError, /Unexpected configuration options.*fubar/)
    end

    it 'can define a crawl with elasticsearch output' do
      config = Crawler::API::Config.new(
        domains:,
        output_sink: :elasticsearch
      )

      expect(config.domain_allowlist.map(&:to_s)).to match_array(expected_allowlist)
      expect(config.seed_urls.map(&:to_s).to_a).to match_array(expected_seed_urls)
      expect(config.output_sink).to eq(:elasticsearch)
      expect(config.output_dir).to be_nil
    end

    it 'can define a crawl with file output' do
      config = Crawler::API::Config.new(
        domains:,
        output_sink: :file,
        output_dir:
      )

      expect(config.domain_allowlist.map(&:to_s)).to match_array(expected_allowlist)
      expect(config.seed_urls.map(&:to_s).to_a).to match_array(expected_seed_urls)
      expect(config.output_sink).to eq(:file)
      expect(config.output_dir).to eq(output_dir)
    end

    it 'should use the console sink by default' do
      config = Crawler::API::Config.new(
        domains:
      )

      expect(config.domain_allowlist.map(&:to_s)).to match_array(expected_allowlist)
      expect(config.seed_urls.map(&:to_s).to_a).to match_array(expected_seed_urls)
      expect(config.output_sink).to eq(:console)
      expect(config.output_dir).to be_nil
    end

    context 'when a domain is missing a main URL' do
      let(:domain2) { { foo: 'bar' } }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Each domain requires a url')
      end
    end

    context 'when a domain URL is invalid' do
      let(:domain2) { { url: 'huh?' } }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Domain "huh?" does not have a URL scheme')
      end
    end

    context 'when a domain URL has a path' do
      let(:domain2) { { url: 'http://domain2.com/baa' } }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Domain "http://domain2.com/baa" cannot have a path')
      end
    end

    context 'when a domain URL is not an HTTP(S) site' do
      let(:domain2) { { url: 'file://location/to/file.txt' } }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Domain "file://location/to/file.txt" is not an HTTP(S) site')
      end
    end

    context 'when domains is empty' do
      let(:domains) { [] }

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Needs at least one domain')
      end
    end

    context 'when crawl rules exist' do
      let(:domain2) do
        {
          url: 'http://domain2.com',
          crawl_rules: [
            { policy: 'deny', pattern: '/blog', type: 'begins' }
          ]
        }
      end

      it 'should create a crawl rule for the domain' do
        config = Crawler::API::Config.new(domains:)

        # nil when no crawl rules are configured
        crawl_rules_d1 = config.crawl_rules['http://domain1.com']
        expect(crawl_rules_d1).to be_nil

        crawl_rules_d2 = config.crawl_rules['http://domain2.com']
        expect(crawl_rules_d2.size).to eq(1)
        expect(crawl_rules_d2.first.policy).to eq(:deny)
      end
    end

    context 'when crawl rules is not an array' do
      let(:domain2) do
        {
          url: 'http://domain2.com',
          crawl_rules: { policy: 'deny', pattern: '/blog', type: 'begins' }
        }
      end

      it 'should raise an argument error' do
        expect do
          Crawler::API::Config.new(
            domains:
          )
        end.to raise_error(ArgumentError, 'Crawl rules for http://domain2.com is not an array')
      end
    end
  end
end
