# frozen_string_literal: true

RSpec.describe 'Response Content-Type support' do
  let(:results) do
    FauxCrawl.crawl_site do
      page '/' do
        body do
          link_to '/html'
          link_to '/pdf'
          link_to '/pdf-multi-header'
        end
      end

      page '/html' do
        headers 'Content-Type' => 'text/html; charset=UTF-8'
      end

      page '/pdf' do
        headers 'Content-Type' => 'application/pdf'
      end

      page '/pdf-multi-header' do
        headers 'Content-Type' => ['application/pdf', 'text/html; charset=UTF-8']
      end
    end
  end

  it 'supports single and multiple Content-Type headers' do
    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/html', status_code: 200)
    ]
  end
end
