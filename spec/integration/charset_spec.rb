# frozen_string_literal: true

RSpec.describe 'Content charset' do
  let(:site) do
    Faux.site do
      page '/' do
        body do
          link_to '/utf8-without-charset'
          link_to '/utf8-with-charset'
        end
      end

      page '/utf8-with-charset' do
        headers 'Content-Type' => 'text/html; charset=UTF-8'
        body do
          text { "ma\u00F1ana ol\u00E9" }
        end
      end

      page '/utf8-without-charset' do
        headers 'Content-Type' => 'text/html'
        body do
          text { "ma\u00F1ana ol\u00E9" }
        end
      end
    end
  end

  it 'defaults to UTF-8' do
    results = FauxCrawl.run(site)

    expect(results).to have_only_these_results [
      mock_response(:url => 'http://127.0.0.1:9393/', :status_code => 200),
      mock_response(:url => 'http://127.0.0.1:9393/utf8-with-charset', :status_code => 200, :content => "<html><body>ma\u00F1ana ol\u00E9</body></html>"),
      mock_response(:url => 'http://127.0.0.1:9393/utf8-without-charset', :status_code => 200, :content => "<html><body>ma\u00F1ana ol\u00E9</body></html>")
    ]
  end

  it 'can override fallback encoding' do
    results = FauxCrawl.run(site, :default_encoding => 'ISO-8859-1')

    expect(results).to have_only_these_results [
      mock_response(:url => 'http://127.0.0.1:9393/', :status_code => 200),
      mock_response(:url => 'http://127.0.0.1:9393/utf8-with-charset', :status_code => 200, :content => "<html><body>ma\u00F1ana ol\u00E9</body></html>"),
      mock_response(:url => 'http://127.0.0.1:9393/utf8-without-charset', :status_code => 200, :content => String.new("<html><body>ma\xC3\xB1ana ol\xC3\xA9</body></html>", :encoding => 'ISO-8859-1'))
    ]
  end
end
