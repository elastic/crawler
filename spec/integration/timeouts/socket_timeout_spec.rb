# frozen_string_literal: true

RSpec.describe 'Request to a site that is very slow to send us any data' do
  let(:site) do
    Faux.site do
      page '/' do
        body do
          link_to '/timeout'
        end
      end

      page '/timeout' do
        def response_body
          sleep 5

          ['Output']
        end
      end
    end
  end

  it 'times out' do
    results = FauxCrawl.run(site, :timeouts => { :socket_timeout => 2 })

    expect(results).to have_only_these_results [
      mock_response(:url => 'http://127.0.0.1:9393/', :status_code => 200)
    ]
  end
end
