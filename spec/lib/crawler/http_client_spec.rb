# frozen_string_literal: true

require 'webrick/httpproxy'

RSpec.describe(Crawler::HttpClient) do
  let(:client_config) do
    {
      loopback_allowed: false,
      private_networks_allowed: false,
      logger: Logger.new($stdout)
    }
  end
  let(:client) { Crawler::HttpClient.new(client_config) }

  #-------------------------------------------------------------------------------------------------
  let(:site_server_settings) do
    {
      port: 12_345,
      debug: true
    }
  end
  let(:site) { Faux.site { page '/' } }
  let(:site_server) { Faux::Site.new(site, site_server_settings) }

  #-------------------------------------------------------------------------------------------------
  # Stubs DNS resolution in HTTP client to always return localhost IPs
  def stub_http_resolver!
    allow_any_instance_of(Crawler::HttpUtils::FilteringDnsResolver).to receive(:resolve) do |resolver, _host|
      resolver.default_resolver.resolve('localhost')
    end
  end

  # Runs a given block of code with a site running on localhost:12345
  def with_example_site
    site_server # start the site
    stub_http_resolver!
    sleep(1)
    yield
  ensure
    site_server.stop
  end

  #-------------------------------------------------------------------------------------------------
  context '#get' do
    def get(url)
      client.get(Crawler::Data::URL.parse(url))
    end

    def expect_result(url, result_code)
      result = get(url)
      expect(result).to be_a(Crawler::HttpUtils::Response)
      expect(result.code).to eq(result_code)
    end

    def expect_success(url)
      expect_result(url, 200)
    end

    it 'should work' do
      expect_success('https://www.elastic.co')
    end

    it 'should not follow redirects automatically' do
      result = get('http://www.elastic.co')
      expect(result.code).to eq(301)
      expect(result.headers['location']).to eq('https://www.elastic.co/')
    end

    it 'rejects loopback addresses' do
      expect do
        get('http://localhost:9200').body
      end.to raise_error(Crawler::HttpUtils::InvalidHost)
    end

    it 'rejects private addresses' do
      expect do
        get('http://monitoring.swiftype.net').body
      end.to raise_error(Crawler::HttpUtils::InvalidHost)
    end

    #-----------------------------------------------------------------------------------------------
    context 'with a configured timeout' do
      let(:client_config) do
        super().merge(
          loopback_allowed: true,
          connection_request_timeout: 10
        )
      end

      context 'for a slow site' do
        let(:site) { Faux.site { page('/') { sleep 15 } } }

        it 'should timeout' do
          with_example_site do
            expect do
              get('http://localhost:12345')
            end.to raise_error(Crawler::HttpUtils::SocketTimeout, /Read timed out/)
          end
        end
      end

      context 'for a site that responds before configured timeout' do
        let(:site) { Faux.site { page('/') { sleep 5 } } }

        it 'should not timeout' do
          with_example_site do
            expect_success('http://localhost:12345')
          end
        end
      end
    end

    #-----------------------------------------------------------------------------------------------
    context 'with a proxy server configuration' do
      let(:proxy_port) { 12_346 }
      let(:client_config) do
        super().merge(
          loopback_allowed: true,
          http_proxy_host: 'localhost',
          http_proxy_port: proxy_port
        )
      end

      let(:proxy_requests) { [] }

      let(:proxy_handler) do
        proc do |request, _response|
          proxy_requests << request
        end
      end

      let(:proxy_auth_proc) { nil }
      let(:proxy) do
        WEBrick::HTTPProxyServer.new(
          Port: proxy_port,
          AccessLog: [
            [$stderr, WEBrick::AccessLog::COMMON_LOG_FORMAT],
            [$stderr, WEBrick::AccessLog::REFERER_LOG_FORMAT]
          ],
          ProxyContentHandler: proxy_handler,
          ProxyAuthProc: proxy_auth_proc
        )
      end

      def with_proxy
        Thread.new { proxy.start }
        sleep(1)
        yield
      ensure
        proxy.shutdown
      end

      it 'should use the proxy' do
        with_proxy do
          with_example_site do
            expect_result('http://localhost:12345', 200)
            expect_result('http://localhost:12345/hello', 404)
            expect(proxy_requests.count).to eq(2)
            expect(proxy_requests.map(&:path)).to eq(['/', '/hello'])
          end
        end
      end

      context 'with proxy auth enabled' do
        let(:proxy_user) { 'hello_user' }
        let(:proxy_pass) { 'paZZZwd' }

        let(:client_config) do
          super().merge(
            http_proxy_username: proxy_user,
            http_proxy_password: proxy_pass
          )
        end

        # Make sure the proxy checks auth headers
        let(:proxy_auth_proc) do
          proc do |req, res|
            auth = req['proxy-authorization']
            unless auth
              # First time HTTP client sends a request, it won't include the auth header
              # We respond with a 407 here and ask for credentials, forcing the client to retry
              res['Proxy-Authenticate'] = 'Basic realm="WEBrick Proxy"'
              raise WEBrick::HTTPStatus::ProxyAuthenticationRequired, 'No auth header!'
            end

            _auth_type, auth_string = auth.split(' ', 2)
            user, password = Base64.strict_decode64(auth_string).split(':', 2)
            raise WEBrick::HTTPStatus::ProxyAuthenticationRequired unless user == proxy_user && password == proxy_pass
          end
        end

        it 'should work' do
          with_proxy do
            with_example_site do
              expect_result('http://localhost:12345', 200)
              expect_result('http://localhost:12345/hello', 404)
              expect(proxy_requests.count).to eq(2)
              expect(proxy_requests.map(&:path)).to eq(['/', '/hello'])
            end
          end
        end

        context 'with invalid proxy credentials' do
          let(:client_config) do
            super().merge(http_proxy_password: 'banana')
          end

          it 'should fail properly' do
            with_proxy do
              with_example_site do
                expect_result('http://localhost:12345', 407)
                expect(proxy_requests).to be_empty
              end
            end
          end
        end
      end
    end

    #-----------------------------------------------------------------------------------------------
    context 'content encoding' do
      let(:client_config) do
        super().merge(loopback_allowed: true)
      end

      let(:mock_requests) { [] }

      let(:mock_handler) do
        proc do |request, _response|
          mock_requests << request
        end
      end

      let(:mock_server) do
        WEBrick::HTTPServer.new(
          Port: 12_347,
          RequestCallback: mock_handler
        )
      end

      def with_mock_server
        Thread.new { mock_server.start }
        sleep(1)
        yield
      ensure
        mock_server.shutdown
      end

      it 'should set the Accept-Encoding header by default' do
        with_mock_server do
          get('http://localhost:12347/')
          expect(mock_requests.first.accept_encoding.sort).to eq(
            Crawler::HttpClient::CONTENT_DECODERS.keys.sort
          )
        end
      end

      context 'with compression disabled' do
        let(:client_config) do
          super().merge(compression_enabled: false)
        end

        it 'should not set the Accept-Encoding header' do
          with_mock_server do
            get('http://localhost:12347/')
            expect(mock_requests.first.accept_encoding.sort).to be_empty
          end
        end
      end
    end
    #-----------------------------------------------------------------------------------------------
    context 'with SSL settings' do
      let(:ca_certs) { [] }
      let(:ssl_mode) { 'full' }
      let(:url) { 'https://example.org' }

      let(:crawler_config) do
        Crawler::API::Config.new(
          domain_allowlist: [url],
          seed_urls: [url],
          ssl_ca_certificates: ca_certs,
          ssl_verification_mode: ssl_mode
        )
      end

      let(:client_config) do
        super().merge(
          loopback_allowed: true,
          ssl_ca_certificates: crawler_config.ssl_ca_certificates,
          ssl_verification_mode: crawler_config.ssl_verification_mode
        )
      end

      let(:ssl_fixture) { 'self-signed' }
      let(:site_server_settings) do
        super().merge(
          ssl: true,
          ssl_certificate: fixture_file('ssl', ssl_fixture, 'example.crt'),
          ssl_key: fixture_file('ssl', ssl_fixture, 'example.key')
        )
      end

      it 'should work with public certificates' do
        expect_success('https://www.elastic.co')
      end

      it 'should fail SSL handshake with self-signed certs' do
        with_example_site do
          expect { get('https://example.org:12345') }.to raise_error(
            Crawler::HttpUtils::SslException,
            /unable to find valid certification path/
          )
        end
      end

      context 'when custom CA certs are configured' do
        let(:ca_certs) { [fixture_file('ssl', 'ca.crt')] }

        it 'should still work with public certificates' do
          expect_success('https://www.elastic.co')
        end

        it 'should work with sites signed with the configured CA' do
          with_example_site do
            expect_success('https://example.org:12345')
          end
        end

        it 'should validate server names' do
          with_example_site do
            expect { get('https://localhost:12345') }.to raise_error(
              Crawler::HttpUtils::SslException,
              /doesn't match common name of the certificate subject/
            )
          end
        end

        context 'when seeing an expired SSL certificate' do
          let(:ssl_fixture) { 'expired' }

          it 'should fail' do
            with_example_site do
              expect { get('https://example.org:12345') }.to raise_error(
                Crawler::HttpUtils::SslCertificateExpiredError,
                /SSL certificate expired/
              )
            end
          end
        end

        context 'with ssl_verification_mode=certificate' do
          let(:ssl_mode) { 'certificate' }

          it 'should not validate server names' do
            with_example_site do
              expect_success('https://localhost:12345')
            end
          end

          context 'when seeing an expired SSL certificate' do
            let(:ssl_fixture) { 'expired' }

            it 'should fail' do
              with_example_site do
                expect { get('https://example.org:12345') }.to raise_error(
                  Crawler::HttpUtils::SslCertificateExpiredError,
                  /SSL certificate expired/
                )
              end
            end
          end
        end

        context 'with ssl_verification_mode=none' do
          let(:ssl_mode) { 'none' }

          it 'should not validate server names' do
            with_example_site do
              expect_success('https://localhost:12345')
            end
          end

          context 'when seeing an expired SSL certificate' do
            let(:ssl_fixture) { 'expired' }

            it 'should ignore the failure' do
              with_example_site do
                expect_success('https://localhost:12345')
              end
            end
          end
        end
      end
    end
  end
end
