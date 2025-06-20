#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe 'Headers' do
  let(:site1) do
    Faux.site do
      page '/' do
        def response_status
          @env['HTTP_AUTHORIZATION'] == 'Basic YmFuYW5hOlNFQ1JFVA==' ? 200 : 404
        end
      end
    end
  end

  let(:site2) do
    Faux.site do
      page '/' do
        def response_status
          @env['HTTP_AUTHORIZATION'] == 'Bearer xyz' ? 200 : 404
        end
      end
    end
  end

  it 'supports basic auth' do
    results = FauxCrawl.run(
      site1,
      url: Crawler::Data::URL.parse(FauxCrawl::Settings.faux_url).site,
      auth:
        {
          type: 'basic',
          username: 'banana',
          password: 'SECRET'
        }
    )

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200)
    ]
  end

  it 'supports raw Authorization header' do
    results = FauxCrawl.run(
      site2,
      url: Crawler::Data::URL.parse(FauxCrawl::Settings.faux_url).site,
      auth:
        {
          type: 'raw',
          header: 'Bearer xyz'
        }
    )

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200)
    ]
  end
end
