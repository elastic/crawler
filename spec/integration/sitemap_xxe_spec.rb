# frozen_string_literal: true

RSpec.describe 'Sitemap XXE vulnerability specs' do
  DO_NOT_VISIT_TXT_PATH = File.expand_path(File.join(FIXTURES_HOME, 'do-not-visit.txt'))
  SITEMAP_XML = <<~XML
    <?xml version="1.0" encoding="utf-8"?>
    <!DOCTYPE urlset [
      <!ENTITY test SYSTEM "file:///#{DO_NOT_VISIT_TXT_PATH}">
    ]>

    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">
      <url>
        <loc>http://127.0.0.1:9393/</loc>
        <lastmod>2019-06-19</lastmod>
        <changefreq>daily</changefreq>
      </url>
      <url>
        <loc>http://127.0.0.1:9393/visit-here</loc>
        <lastmod>2019-06-19</lastmod>
        <changefreq>daily</changefreq>
      </url>
      <url>
        <loc>&test;</loc>
        <lastmod>2019-06-19</lastmod>
        <changefreq>daily</changefreq>
      </url>
    </urlset>
  XML

  let(:results) { FauxCrawl.run(site) }

  context 'sitemap' do
    let(:site) do
      Faux.site do
        robots do
          user_agent '*'
          sitemap '/sitemap.xml'
        end

        sitemap '/sitemap.xml' do
          def response_body
            [SITEMAP_XML]
          end
        end

        page '/visit-here'
      end
    end

    it 'extracts links but does not look up files' do
      expect(results).to have_only_these_results [
        mock_response(url: 'http://127.0.0.1:9393/', status_code: 404),
        mock_response(url: 'http://127.0.0.1:9393/visit-here', status_code: 200)
      ]
    end
  end

  context 'gzipped sitemap' do
    let(:site) do
      Faux.site do
        robots do
          user_agent '*'
          sitemap '/sitemap.xml'
        end

        sitemap '/sitemap.xml' do
          def response_body
            [gzip(SITEMAP_XML)]
          end
        end

        page '/visit-here'
      end
    end

    it 'extracts links but does not look up files' do
      expect(results).to have_only_these_results [
        mock_response(url: 'http://127.0.0.1:9393/', status_code: 404),
        mock_response(url: 'http://127.0.0.1:9393/visit-here', status_code: 200)
      ]
    end
  end
end
