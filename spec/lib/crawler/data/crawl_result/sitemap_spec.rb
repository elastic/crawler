# frozen_string_literal: true

RSpec.describe(Crawler::Data::CrawlResult::Sitemap) do
  let(:url) { Crawler::Data::URL.parse('https://example.com/sitemap.xml') }
  let(:status_code) { 200 }
  let(:crawl_result) do
    Crawler::Data::CrawlResult::Sitemap.new(
      url: url,
      status_code: status_code,
      content: sitemap_content
    )
  end

  describe '#extract_links' do
    let(:result) { crawl_result.extract_links }
    let(:links) { result[:links] }
    let(:content_links) { links[:content].map(&:to_url).map(&:to_s) }
    let(:sitemap_links) { links[:sitemap].map(&:to_url).map(&:to_s) }

    context 'when given a sitemap index' do
      let(:sitemap_content) { fixture_xml('sitemap', 'sitemap_index') }

      it 'should return a set of sitemap links' do
        expect(sitemap_links).to eq [
          'http://www.example.com/sitemap1.xml',
          'http://www.example.com/sitemap2.xml'
        ]
      end

      it 'should not return any content links' do
        expect(content_links).to be_empty
      end

      it 'should not return any errors' do
        expect(result[:error]).to be_nil
      end

      #---------------------------------------------------------------------------------------------
      context 'with more URLs than allowed by the spec' do
        let(:sitemap_content) { fixture_xml('sitemap', 'sitemap_index_huge') }

        it 'should return whatever fits within the limit' do
          expect(links[:sitemap].size).to eq(50_001)
        end

        it 'should not return any errors' do
          expect(result[:error]).to be_nil
        end
      end

      #---------------------------------------------------------------------------------------------
      context 'containing links wrapped in CDATA' do
        let(:sitemap_content) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <sitemap><loc><![CDATA[http://www.swiftype.com.com/sitemap-1.xml]]></loc></sitemap>
              <sitemap><loc><![CDATA[http://www.swiftype.com/sitemap-2.xml]]></loc></sitemap>
              <sitemap><loc>http://www.swiftype.com/sitemap-3.xml</loc></sitemap>
            </sitemapindex>
          XML
        end

        it 'should return a set of sitemap links' do
          expect(sitemap_links).to eq [
            'http://www.swiftype.com.com/sitemap-1.xml',
            'http://www.swiftype.com/sitemap-2.xml',
            'http://www.swiftype.com/sitemap-3.xml'
          ]
        end

        it 'should not return any errors' do
          expect(result[:error]).to be_nil
        end
      end

      #---------------------------------------------------------------------------------------------
      context 'containing corrupted XML' do
        let(:sitemap_content) { '>>>>blergh!%&<<<<' }

        it 'should return an empty set of URLs' do
          expect(sitemap_links).to be_empty
        end

        it 'should return an error explaining the problem' do
          expect(result[:error]).to match(/Failed to parse sitemap/)
        end

        context 'where a part of the XML is valid' do
          let(:sitemap_content) do
            <<~XML
              <?xml version="1.0" encoding="UTF-8"?>
              <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
                <sitemap><loc>http://www.swiftype.com/sitemap-1.xml</loc></sitemap>
                >>>>blergh!%&<<<<
                <sitemap><loc>http://www.swiftype.com/sitemap-2.xml</loc></sitemap>
            XML
          end

          it 'should return a partial set of URLs' do
            expect(sitemap_links).to eq ['http://www.swiftype.com/sitemap-1.xml']
          end

          it 'should not return any errors' do
            expect(result[:error]).to be_nil
          end
        end
      end
    end

    #-----------------------------------------------------------------------------------------------
    context 'when given a sitemap' do
      let(:sitemap_content) { fixture_xml('sitemap', 'sitemap_urlset') }

      it 'should return a list of content urls' do
        expect(content_links).to eq [
          'http://www.example.com/',
          'http://www.example.com/catalog?item=12&desc=vacation_hawaii',
          'http://www.example.com/catalog?item=73&desc=vacation_new_zealand',
          'http://www.example.com/catalog?item=74&desc=vacation_newfoundland',
          'http://www.example.com/catalog?item=83&desc=vacation_usa'
        ]
      end

      it 'should not return any sitemap links' do
        expect(sitemap_links).to be_empty
      end

      #---------------------------------------------------------------------------------------------
      context 'with more URLs than allowed by the spec' do
        let(:sitemap_content) { fixture_xml('sitemap', 'sitemap_urlset_huge') }

        it 'should return whatever fits within the limit' do
          expect(links[:content].size).to eq(50_001)
        end

        it 'should not return any errors' do
          expect(result[:error]).to be_nil
        end
      end

      #---------------------------------------------------------------------------------------------
      context 'compressed with GZip' do
        let(:sitemap_content) { fixture_xml_gz('sitemap', 'sitemap_urlset') }

        it 'should return a list of content urls' do
          expect(content_links).to eq [
            'http://www.matthewriley.com/',
            'http://www.matthewriley.com/new_crawl/3.html',
            'http://www.matthewriley.com/new_crawl/4.html',
            'http://www.matthewriley.com/new_crawl/5.html',
            'http://www.matthewriley.com/new_crawl/6.html',
            'http://www.matthewriley.com/projects/video/'
          ]
        end

        it 'should not return any errors' do
          expect(result[:error]).to be_nil
        end
      end

      #---------------------------------------------------------------------------------------------
      context 'containing a BOM-prefix' do
        let(:bom) { [239, 187, 191].pack('c*').force_encoding('UTF-8') }
        let(:sitemap_content) do
          bom + <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc>http://example.com/baz</loc></url>
            </urlset>
          XML
        end

        it 'should return a list of content urls' do
          expect(content_links).to eq ['http://example.com/baz']
        end

        it 'should not return any errors' do
          expect(result[:error]).to be_nil
        end
      end

      #---------------------------------------------------------------------------------------------
      context 'containing links wrapped in CDATA' do
        let(:sitemap_content) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
              <url><loc><![CDATA[http://www.swiftype.com.com/foo]]></loc></url>
              <url><loc><![CDATA[http://www.swiftype.com/bar]]></loc></url>
              <url><loc>http://www.swiftype.com/something</loc></url>
            </urlset>
          XML
        end

        it 'should return a list of content urls' do
          expect(content_links).to eq [
            'http://www.swiftype.com.com/foo',
            'http://www.swiftype.com/bar',
            'http://www.swiftype.com/something'
          ]
        end

        it 'should not return any errors' do
          expect(result[:error]).to be_nil
        end
      end

      #---------------------------------------------------------------------------------------------
      context 'containing corrupted XML' do
        let(:sitemap_content) { '>>>>blergh!%&<<<<' }

        it 'should return an empty set of URLs' do
          expect(sitemap_links).to be_empty
        end

        it 'should return an error explaining the problem' do
          expect(result[:error]).to match(/Failed to parse sitemap/)
        end

        context 'where a part of the XML is valid' do
          let(:sitemap_content) do
            <<~XML
              <?xml version="1.0" encoding="UTF-8"?>
              <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
                <url><loc>http://www.swiftype.com.com/foo</loc></url>
                >>>>blergh!%&<<<<
                <url><loc>http://www.swiftype.com/something</loc></url>
            XML
          end

          it 'should return a partial set of URLs' do
            expect(content_links).to eq ['http://www.swiftype.com.com/foo']
          end

          it 'should not return any errors' do
            expect(result[:error]).to be_nil
          end
        end
      end
    end
  end
end
