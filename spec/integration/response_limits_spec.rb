# frozen_string_literal: true

# Generate a large enough random string that would require multiple TCP-packets to download
require 'securerandom'
MULTI_CHUNK_BODY = SecureRandom.alphanumeric(12_345)

RSpec.describe 'Per-request resource limits support' do
  let(:results) do
    FauxCrawl.crawl_site do
      page '/' do
        body do
          link_to '/multi-chunk'
          link_to '/too-big'
        end
      end

      # Should be indexed, downloads will produce multiple chunks
      page '/multi-chunk' do
        def response_body
          [MULTI_CHUNK_BODY]
        end
      end

      # Should not be indexed because it is too big
      page '/too-big' do
        def response_body
          ['x' * 11_000_000]
        end
      end
    end
  end

  it 'crawls all pages given the constraints specified by resource limits' do
    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/multi-chunk', status_code: 200)
    ]
  end

  it 'should correctly download multi-chunk responses' do
    multi_chunk_response = results.find { |r| r.url.to_s =~ /multi-chunk$/ }
    expect(multi_chunk_response.content).to eq(MULTI_CHUNK_BODY)
  end
end
