# frozen_string_literal: true

RSpec.describe(Crawler::HttpExecutor) do
  let(:url) { 'https://example.com' }
  let(:crawler_url) { Crawler::Data::URL.parse(url) }
  let(:normalized_url) { crawler_url.normalized_url }

  let(:logger) { double(:logger, :info => nil) }
  let(:system_logger) { double(:system_logger) }
  let(:executor_config) do
    double(
      :executor_config,
      :system_logger => system_logger,
      :user_agent => 'Elastic-Crawler (1.0.0)',
      :loopback_allowed => false,
      :private_networks_allowed => false,
      :connect_timeout => 10,
      :socket_timeout => 10,
      :request_timeout => 60,
      :ssl_ca_certificates => [],
      :ssl_verification_mode => 'full',
      :http_proxy_host => nil,
      :http_proxy_port => nil,
      :http_proxy_username => nil,
      :http_proxy_password => nil,
      :http_proxy_protocol => nil,
      :compression_enabled => true,
      :default_encoding => 'UTF-8',
      :max_response_size => 10.megabytes,
      :max_redirects => 10,
      :content_extraction_enabled => false,
      :content_extraction_mime_types => [],
      :head_requests_enabled => true
    )
  end
  let(:http_executor) do
    Crawler::HttpExecutor.new(executor_config)
  end

  let(:crawl_task) { Crawler::Data::CrawlTask.new(:url => crawler_url, :type => :content, :depth => 1) }

  let(:client_config) do
    {
      :loopback_allowed => false,
      :private_networks_allowed => false,
      :logger => Logger.new(STDOUT)
    }
  end
  let(:http_client) { Crawler::HttpClient.new(client_config) }

  let(:content_type_header) do
    double(
      :content_type_header,
      :value => 'text/html',
      :get_value => 'text/html',
      :get_name => 'content-type'
    )
  end
  let(:response_entity) do
    double(
      :response_entity,
      :content_type => 'text/html; charset=utf-8',
      :content => nil
    )
  end
  let(:head_response) do
    double(
      :apache_response,
      :status_code => 200,
      :close => true,
      :headers => [content_type_header],
      :entity => nil
    )
  end
  let(:get_response) do
    double(
      :apache_response,
      :status_code => 200,
      :close => true,
      :headers => [content_type_header],
      :entity => response_entity
    )
  end

  let(:crawler_head_response) do
    Crawler::HttpClient::Response.new(
      :apache_response => head_response,
      :url => crawler_url,
      :request_start_time => 2.seconds.ago,
      :request_end_time => 1.second.ago
    )
  end
  let(:crawler_get_response) do
    Crawler::HttpClient::Response.new(
      :apache_response => get_response,
      :url => crawler_url,
      :request_start_time => 2.seconds.ago,
      :request_end_time => 1.second.ago
    )
  end

  before do
    allow(head_response).to receive(:getVersion)
    allow(head_response).to receive(:getCode).and_return(200)
    allow(head_response).to receive(:getReasonPhrase)

    allow(get_response).to receive(:getVersion)
    allow(get_response).to receive(:getCode).and_return(200)
    allow(get_response).to receive(:getReasonPhrase)

    allow(system_logger).to receive(:tagged).with(:http).and_return(logger)

    allow(Crawler::HttpClient).to receive(:new).and_return(http_client)
    allow(http_client).to receive(:head).and_return(crawler_head_response)
    allow(http_client).to receive(:get).and_return(crawler_get_response)
  end

  it 'calls HEAD then GET once each' do
    http_executor.run(crawl_task)

    expect(http_client).to have_received(:head).once
    expect(http_client).to have_received(:get).once
  end

  context 'when head_requests_enabled is false' do
    before do
      allow(executor_config).to receive(:head_requests_enabled).and_return(false)
    end

    it 'calls GET once' do
      http_executor.run(crawl_task)

      expect(http_client).not_to have_received(:head)
      expect(http_client).to have_received(:get).once
    end
  end

  context 'when HEAD returns an error' do
    let(:head_response) do
      double(
        :apache_response,
        :status_code => 405,
        :close => true,
        :headers => [],
        :entity => nil
      )
    end

    before do
      allow(head_response).to receive(:getCode).and_return(405)
    end

    it 'continues on to call GET' do
      http_executor.run(crawl_task)

      expect(http_client).to have_received(:head).once
      expect(http_client).to have_received(:get).once
    end
  end

  context 'when HEAD returns a redirect' do
    let(:redirect_url) { 'https://example.com/info' }
    let(:crawler_redirect_url) { Crawler::Data::URL.parse(redirect_url) }
    let(:normalized_redirect_url) { crawler_redirect_url.normalized_url }

    let(:redirect_header) do
      double(
        :redirect_header,
        :value => redirect_url,
        :get_value => redirect_url,
        :get_name => 'location'
      )
    end
    let(:redirect_head_response) do
      double(
        :apache_response,
        :status_code => 304,
        :close => true,
        :entity => nil,
        :headers => [redirect_header]
      )
    end

    let(:redirect_crawler_head_response) do
      Crawler::HttpClient::Response.new(
        :apache_response => redirect_head_response,
        :url => crawler_redirect_url,
        :request_start_time => 2.seconds.ago,
        :request_end_time => 1.second.ago
      )
    end

    before do
      allow(redirect_head_response).to receive(:getVersion)
      allow(redirect_head_response).to receive(:getCode).and_return(304)
      allow(redirect_head_response).to receive(:getReasonPhrase)

      allow(http_client).to receive(:head).and_return(redirect_crawler_head_response, crawler_head_response)
    end

    it 'follows redirect using HEAD if follow_redirects is true' do
      # a redirect using HEAD in this case will call HEAD twice and GET once
      http_executor.run(crawl_task, follow_redirects: true)

      # confirm total requests made
      expect(http_client).to have_received(:head).twice
      expect(http_client).to have_received(:get).once

      # confirm URLs are correct
      expect(http_client).to have_received(:head).with(normalized_url, anything).once
      expect(http_client).to have_received(:head).with(normalized_redirect_url, anything).once
      expect(http_client).to have_received(:get).with(normalized_redirect_url, anything).once
    end

    it 'does not follow redirect if follow_redirects is false' do
      # ignoring redirect should result in HEAD and GET being called once each
      http_executor.run(crawl_task, follow_redirects: false)

      # confirm total requests made
      expect(http_client).to have_received(:head).once
      expect(http_client).to have_received(:get).once

      # confirm URLs are correct
      expect(http_client).to have_received(:head).with(normalized_url, anything).once
      expect(http_client).to have_received(:get).with(normalized_url, anything).once
    end

    context 'when head_requests_enabled is false' do
      let(:redirect_get_response) do
        double(
          :apache_response,
          :status_code => 304,
          :close => true,
          :entity => response_entity,
          :headers => [redirect_header, content_type_header]
        )
      end

      let(:redirect_crawler_get_response) do
        Crawler::HttpClient::Response.new(
          :apache_response => redirect_head_response,
          :url => crawler_redirect_url,
          :request_start_time => 2.seconds.ago,
          :request_end_time => 1.second.ago
        )
      end

      before do
        allow(executor_config).to receive(:head_requests_enabled).and_return(false)
        allow(http_client).to receive(:get).and_return(redirect_crawler_get_response, crawler_get_response)
      end

      it 'follows redirect using GET' do
        http_executor.run(crawl_task, follow_redirects: true)

        # confirm total requests made
        expect(http_client).not_to have_received(:head)
        expect(http_client).to have_received(:get).twice

        # confirm URLs are correct
        expect(http_client).to have_received(:get).with(normalized_url, anything).once
        expect(http_client).to have_received(:get).with(normalized_redirect_url, anything).once
      end
    end
  end

  context 'when content_type is missing' do
    before do
      allow(response_entity).to receive(:content_type).and_return(nil)
    end

    it 'does not encounter an error' do
      http_executor.run(crawl_task)

      expect(http_client).to have_received(:head).once
      expect(http_client).to have_received(:get).once
    end
  end

  context 'with non-default mime-types' do
    before(:example) do
      allow(crawler_head_response).to receive(:release_connection).and_return(false)
    end

    let(:content_type_header) do
      double(
        :content_type_header,
        :value => 'application/pdf',
        :get_value => 'application/pdf',
        :get_name => 'content-type'
      )
    end
    let(:response_entity) do
      double(
        :response_entity,
        :content_type => 'application/pdf; charset=utf-8',
        :content => nil
      )
    end

    it 'returns Crawler::Data::CrawlResult::UnsupportedContentType' do
      expect(http_executor.run(crawl_task)).to be_a(Crawler::Data::CrawlResult::UnsupportedContentType)

      expect(http_client).to have_received(:head).once
      expect(http_client).not_to have_received(:get)
      expect(crawler_head_response).to have_received(:release_connection)
    end

    shared_examples_for 'supported content' do
      it 'does not return Crawler::Data::CrawlResult::UnsupportedContentType' do
        expect(http_executor.run(crawl_task)).not_to be_a(Crawler::Data::CrawlResult::UnsupportedContentType)

        expect(http_client).to have_received(:head).once
        expect(http_client).to have_received(:get).once
      end
    end

    context 'when content_extraction_enabled is true and mime-type is supported' do
      before do
        allow(executor_config).to receive(:content_extraction_enabled).and_return(true)
        allow(executor_config).to receive(:content_extraction_mime_types).and_return(['Application/PDF'])
      end

      it_behaves_like 'supported content'

      context 'when mime-type is XML' do
        let(:content_type_header) do
          double(
            :content_type_header,
            :value => 'application/xml',
            :get_value => 'application/xml',
            :get_name => 'content-type'
          )
        end
        let(:response_entity) do
          double(
            :response_entity,
            :content_type => 'application/xml; charset=utf-8',
            :content => nil
          )
        end

        before(:each) do
          allow(executor_config).to receive(:content_extraction_mime_types).and_return(['Application/XML'])
        end

        it_behaves_like 'supported content'
        it 'emits a content result' do
          expect(http_executor.run(crawl_task)).to be_a(Crawler::Data::CrawlResult::ContentExtractableFile)
        end

        context 'when crawl task is sitemap type' do
          let(:crawl_task) { Crawler::Data::CrawlTask.new(:url => crawler_url, :type => :sitemap, :depth => 1) }
          it_behaves_like 'supported content'
          it 'emits a sitemap result' do
            expect(http_executor.run(crawl_task)).to be_a(Crawler::Data::CrawlResult::Sitemap)
          end
        end
      end
    end

    context 'when content_extraction_enabled is true but mime-type is not supported' do
      before do
        allow(executor_config).to receive(:content_extraction_enabled).and_return(true)
        allow(executor_config).to receive(:content_extraction_mime_types).and_return(['image/png'])
      end

      it 'returns Crawler::Data::CrawlResult::UnsupportedContentType' do
        expect(http_executor.run(crawl_task)).to be_a(Crawler::Data::CrawlResult::UnsupportedContentType)

        expect(http_client).to have_received(:head).once
        expect(http_client).not_to have_received(:get)
      end

      context 'when sitemap with mime-type, XML' do
        let(:content_type_header) do
          double(
            :content_type_header,
            :value => 'application/xml',
            :get_value => 'application/xml',
            :get_name => 'content-type'
          )
        end
        let(:response_entity) do
          double(
            :response_entity,
            :content_type => 'application/xml; charset=utf-8',
            :content => nil
          )
        end
        let(:crawl_task) { Crawler::Data::CrawlTask.new(:url => crawler_url, :type => :sitemap, :depth => 1) }

        it_behaves_like 'supported content'
      end
    end
  end
end
