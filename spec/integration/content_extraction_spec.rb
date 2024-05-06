#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe 'Content extractable file support' do
  let(:site) do
    Faux.site do
      page '/' do
        body do
          link_to '/html'
          link_to '/pdf'
          link_to '/powerpoint'
          link_to '/word'
        end
      end

      page '/html' do
        headers 'Content-Type' => 'text/html; charset=UTF-8'
      end

      page '/pdf' do
        headers 'Content-Type' => 'application/pdf'
      end

      page '/powerpoint' do
        headers 'Content-Type' => 'application/vnd.ms-powerpoint'
      end

      page '/word' do
        headers 'Content-Type' => 'application/msword'
      end
    end
  end

  it 'supports single and multiple Content-Type headers' do
    results = FauxCrawl.run(
      site,
      content_extraction: {
        enabled: true,
        mime_types: [
          'application/pdf',
          'application/vnd.ms-powerpoint'
        ]
      }
    )

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/html', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/pdf', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/powerpoint', status_code: 200)
    ]
  end
end
