#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe 'robots.txt support' do
  let(:site) do
    Faux.site do
      robots do
        user_agent 'Elastic Crawler'
        disallow '/no-elastic-crawler'

        user_agent '*'
        disallow '/sekret-stuff'
      end

      page '/' do
        body do
          link_to '/hey'
          link_to '/no-elastic-crawler'
          link_to '/sekret-stuff'
        end
      end

      page '/hey'
      page '/no-elastic-crawler'
      page '/sekret-stuff'
    end
  end

  it 'should respect robots.txt disallow rules for matching User-Agent' do
    results = FauxCrawl.run(site, user_agent: 'Elastic Crawler')

    expect(results).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/hey', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/sekret-stuff', status_code: 200)
    ]
  end

  it 'should respect robots.txt disallow rules for wildcard User-Agent' do
    crawler = FauxCrawl.run(site, user_agent: 'This Does Not Match')

    expect(crawler).to have_only_these_results [
      mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/hey', status_code: 200),
      mock_response(url: 'http://127.0.0.1:9393/no-elastic-crawler', status_code: 200)
    ]
  end

  context 'without content type' do
    before do
      allow_any_instance_of(Faux::Element::Robots).to receive(:response_headers).and_return({})
    end

    it 'should respect robots.txt disallow rules for matching User-Agent' do
      results = FauxCrawl.run(site, user_agent: 'Elastic Crawler')

      expect(results).to have_only_these_results [
        mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
        mock_response(url: 'http://127.0.0.1:9393/hey', status_code: 200),
        mock_response(url: 'http://127.0.0.1:9393/sekret-stuff', status_code: 200)
      ]
    end
  end

  #-------------------------------------------------------------------------------------------------
  context 'redirects' do
    context 'with a reasonably long redirect chain' do
      let(:site) do
        Faux.site do
          robots '/robots-redirect.txt' do
            user_agent '*'
            disallow '/sekret-stuff'
          end

          page '/robots.txt' do
            redirect '/robots-redirect.txt'
          end

          page '/' do
            body do
              link_to '/hey'
              link_to '/sekret-stuff'
            end
          end

          page '/hey'
          page '/sekret-stuff'
        end
      end

      it 'should follow the redirect and apply the rules' do
        crawler = FauxCrawl.run(site)
        expect(crawler).to have_only_these_results [
          mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
          mock_response(url: 'http://127.0.0.1:9393/hey', status_code: 200)
        ]
      end
    end

    #-----------------------------------------------------------------------------------------------
    context 'with a very long redirect chain' do
      let(:site) do
        Faux.site do
          # Generate a long redirect chain
          21.times do |i|
            page "/robots-redirect-#{i}.txt" do
              redirect "/robots-redirect-#{i + 1}.txt"
            end
          end

          # Create a real robots.txt file at the end of the chain
          robots '/robots-redirect-20.txt' do
            user_agent '*'
            disallow '/sekret-stuff'
          end

          # Redirect robots into the long chain
          page '/robots.txt' do
            redirect '/robots-redirect-0.txt'
          end

          page '/' do
            body do
              link_to '/hey'
              link_to '/sekret-stuff'
            end
          end

          page '/hey'
          page '/sekret-stuff'
        end
      end

      it 'should abort the redirect and allow all due to robots.txt being treated as missing' do
        expect_any_instance_of(Logger).to receive(:warn).with(
          /Purge crawls are not supported for sink type mock. Skipping purge crawl./
        ).at_least(:once).and_call_original
        expect_any_instance_of(Logger).to receive(:warn).with(
          /Not following the HTTP redirect.*because the redirect chain is too long/
        ).at_least(:once).and_call_original

        crawler = FauxCrawl.run(site)
        expect(crawler).to have_only_these_results [
          mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
          mock_response(url: 'http://127.0.0.1:9393/hey', status_code: 200),
          mock_response(url: 'http://127.0.0.1:9393/sekret-stuff', status_code: 200)
        ]
      end
    end
  end

  #-------------------------------------------------------------------------------------------------
  context 'failure' do
    context 'status 4xx' do
      let(:site) do
        Faux.site do
          page '/robots.txt' do
            status 404
          end

          page '/' do
            body do
              link_to '/hey'
              link_to '/sekret-stuff'
            end
          end

          page '/hey'
          page '/sekret-stuff'
        end
      end

      it 'should allow all URLs' do
        results = FauxCrawl.run(site)

        expect(results).to have_only_these_results [
          mock_response(url: 'http://127.0.0.1:9393/', status_code: 200),
          mock_response(url: 'http://127.0.0.1:9393/hey', status_code: 200),
          mock_response(url: 'http://127.0.0.1:9393/sekret-stuff', status_code: 200)
        ]
      end
    end

    #-----------------------------------------------------------------------------------------------
    context 'status 5xx' do
      let(:site) do
        Faux.site do
          page '/robots.txt' do
            status 500
          end

          page '/' do
            body do
              link_to '/hey'
              link_to '/sekret-stuff'
            end
          end

          page '/hey'
          page '/sekret-stuff'
        end
      end

      it 'should deny all URLs' do
        results = FauxCrawl.run(site)

        expect(results).to have_only_these_results []
      end
    end
  end
end
