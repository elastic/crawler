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

  let(:site3) do
    Faux.site do
      page '/' do
        def response_status
          @env['HTTP_AUTHORIZATION'] ? 404 : 200
        end
      end
    end
  end

  let(:site4) do
    Faux.site do
      page '/' do
        def response_status
          @env['HTTP_AUTHORIZATION'] == 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkb29yX3Bhc3Nfa' ? 200 : 404
        end
      end
    end
  end

  it 'supports basic auth' do
    results = FauxCrawl.run(
      site1,
      auth: [
        {
          domain: Crawler::Data::URL.parse(FauxCrawl::Settings.faux_url).site,
          type: 'basic',
          username: 'banana',
          password: 'SECRET'
        }
      ]
    )

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200)
    ]
  end

  it 'supports raw Authorization header' do
    results = FauxCrawl.run(
      site2,
      auth: [
        {
          domain: Crawler::Data::URL.parse(FauxCrawl::Settings.faux_url).site,
          type: 'raw',
          header: 'Bearer xyz'
        }
      ]
    )

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200)
    ]
  end

  it 'does not set Authorization header for non-matching domain' do
    results = FauxCrawl.run(
      site3,
      auth: [
        {
          domain: 'http://example.com',
          type: 'raw',
          header: 'Bearer xyz'
        }
      ]
    )

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200)
    ]
  end

  it 'supports JWT authorization header' do
    results = FauxCrawl.run(
      site4,
      auth: [
        {
          domain: Crawler::Data::URL.parse(FauxCrawl::Settings.faux_url).site,
          type: 'jwt',
          jwt_token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkb29yX3Bhc3Nfa'
        }
      ]
    )

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200)
    ]
  end
end
