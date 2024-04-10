# frozen_string_literal: true

RSpec.describe(Crawler::RobotsTxtParser) do
  let(:base_url) { 'http://example.com' }
  let(:robots_text) do
    <<-EOL
    User-agent: *
    Allow: /
    EOL
  end
  let(:robot_parser) { described_class.new(robots_text, base_url: base_url) }

  context '#sitemaps' do
    context 'when robots.txt points to absolute URL sitemap' do
      let(:custom_sitemap) { 'http://example.com/absolute-sitemap.xml' }
      let(:robots_text) do
        <<-EOL
        User-agent: *
        Disallow: /sso

        Sitemap: #{custom_sitemap}
        EOL
      end

      it 'returns sitemap specified in robots.txt' do
        expect(robot_parser.sitemaps.size).to eq 1
        expect(robot_parser.sitemaps).to include(custom_sitemap)
      end
    end

    context 'when robots.txt points to relative path sitemap' do
      let(:custom_sitemap) { '/relative-sitemap.xml' }
      let(:robots_text) do
        <<-EOL
        User-agent: *
        Disallow: /sso

        Sitemap: #{custom_sitemap}
        EOL
      end

      it 'returns sitemap specified in robots.txt' do
        expect(robot_parser.sitemaps.size).to eq 1
        expect(robot_parser.sitemaps).to include("#{base_url}#{custom_sitemap}")
      end
    end
  end

  context '#crawl_delay' do
    context 'when crawl_delay is specified' do
      let(:crawl_delay) { 60 }
      let(:robots_text) do
        <<-EOL
        User-agent: *
        Crawl-delay: #{crawl_delay}
        EOL
      end

      it 'returns the number to wait' do
        expect(robot_parser.crawl_delay).to eq crawl_delay
      end
    end

    context 'when crawl_delay is not specified in robots.txt' do
      it 'returns nil' do
        expect(robot_parser.crawl_delay).to eq nil
      end
    end
  end

  context '#allowed?' do
    context 'when robots.txt has specific settings for our user agent' do
      let(:robots_text) do
        <<~EOL
          User-agent: *
          Disallow: /not-by-default

          User-agent: Elastic-Crawler
          Disallow: /not-for-elastic

          User-agent: Google-Bot
          Disallow: /not-for-google
        EOL
      end

      it 'should use the crawler-specific directives block' do
        expect(robot_parser.allowed?('/not-by-default')).to be(true)
        expect(robot_parser.allowed?('/not-for-elastic')).to be(false)
      end

      it 'should ignore directives for other bots' do
        expect(robot_parser.allowed?('/not-for-google')).to be(true)
      end
    end

    context 'when robots.txt disallows the path' do
      let(:robots_text) do
        <<-EOL
        User-agent: *
        Disallow: /sso
        EOL
      end

      it 'marks path as disallowed' do
        expect(robot_parser.allowed?('/sso')).to eq false
        expect(robot_parser.allowed?('/something-else')).to eq true
      end
    end

    context 'when robots.txt has non-USASCII bytes in it' do
      let(:robots_text) do
        bad_char = "\xE2"
        (+<<-EOL).force_encoding('ASCII-8BIT')
          User-agent: *
          Disallow: /sso
          #{bad_char}
        EOL
      end

      it 'marks path as allowed or disallowed as appropriate' do
        expect(robot_parser.allowed?('/sso')).to eq false
        expect(robot_parser.allowed?('/something-else')).to eq true
      end
    end
  end

  context 'failure: 4xx' do
    let(:robot_parser) { described_class::Failure.new(base_url: base_url, status_code: 404) }

    describe '#sitemaps' do
      it 'returns empty array' do
        expect(robot_parser.sitemaps).to eq([])
      end
    end

    describe '#allowed?' do
      it 'allows anything' do
        expect(robot_parser.allowed?('/test')).to eq(true)
        expect(robot_parser.allowed?('/sekret')).to eq(true)
      end
    end
  end

  context 'failure: 5xx' do
    let(:robot_parser) { described_class::Failure.new(base_url: base_url, status_code: 500) }

    describe '#sitemaps' do
      it 'returns empty array' do
        expect(robot_parser.sitemaps).to eq([])
      end
    end

    describe '#allowed?' do
      it 'allows nothing' do
        expect(robot_parser.allowed?('/test')).to eq(false)
        expect(robot_parser.allowed?('/sekret')).to eq(false)
      end
    end
  end
end
