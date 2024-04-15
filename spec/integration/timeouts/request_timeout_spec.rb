# frozen_string_literal: true

require 'socket'

RSpec.describe 'Request to a site that is sending the data back really slowly' do
  # rubocop:disable Lint/ConstantDefinitionInBlock
  class VerySlowServer
    PORT = 10_000
    RESPONSE_DURATION = 20 # seconds
    ROOT_PAGE = <<~HTML
      <html>
        <body>
          <a href="/timeout">Timeout page is here</a>
        </body>
      </html>
    HTML

    def root_url
      "http://127.0.0.1:#{PORT}"
    end

    def start
      TCPServer.open('127.0.0.1', PORT) do |serv|
        loop do
          sock = serv.accept
          req = sock.gets("\r\n\r\n")
          handle_request(req, sock)
        ensure
          sock&.close
        end
      end
    end

    def handle_request(req, sock) # rubocop:disable Metrics/MethodLength
      sock.print "HTTP/1.0 200 OK\r\n"
      sock.print "Content-Type: text/html\r\n"
      if req.start_with?('GET /timeout')
        #
        # If the server provides a content length, Apache HTTP client does not
        # allow us to close the connection prematurely and keeps reading the content
        # until it reaches the end or until 2048 bytes have been consumed
        #
        # So, to make the test faster, we do not send a content length yet.
        # When the issue is fixed, we should remove the comment here.
        #
        # sock.print "Content-Length: 80\r\n"
        #
        sock.print "\r\n"

        puts 'Slowly sending response lines...'
        RESPONSE_DURATION.times do |i|
          sleep 1
          sock.print "no\r\n"
          puts "[#{i}] One... line... at... a... time... "
        end
      else
        root_page_payload = "#{ROOT_PAGE}\r\n"
        sock.print "Content-Length: #{root_page_payload.length}\r\n\r\n"
        sock.print root_page_payload
      end
    end
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock

  it 'times out' do
    # Start a very slow server on a separate port
    slow_server = VerySlowServer.new
    slow_thread = Thread.new { slow_server.start }

    # Configure and run a crawl against the slow server
    results = FauxCrawl.run(
      Faux.site, # This will never actually be called, since we seed the crawl with the slow site
      timeouts: { request_timeout: 2 },
      seed_urls: [slow_server.root_url]
    )

    # Should only have a single result (home page)
    expect(results).to have_only_these_results [
      mock_response(url: "#{slow_server.root_url}/", status_code: 200)
    ]

    # Should properly count visited pages
    stats = results.crawl.stats
    expect(stats.status_code_counts).to eq(
      '200' => 2, # robots.txt + home page
      '599' => 1  # /timeout
    )

    # Should properly enforce the timeout
    expect(stats.time_spent_crawling_msec).to be < VerySlowServer::RESPONSE_DURATION * 1000
  ensure
    slow_thread.kill
  end
end
