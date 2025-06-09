#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

RSpec.describe(Crawler::OutputSink::File) do
  let(:domains) { [{ url: 'http://example.com' }] }

  context '#initialize' do
    def new_sink(config)
      Crawler::OutputSink::File.new(config)
    end

    it 'has a default output directory of ./crawled_docs' do
      config = Crawler::API::Config.new(
        domains:,
        output_sink: './crawled_docs'
      )

      expect { new_sink(config) }.to_not raise_error
      expect(config.output_dir).to eq('./crawled_docs')
    end

    it 'should create the output directory' do
      dir = '/some/directory'
      config = Crawler::API::Config.new(
        domains:,
        output_sink: 'file',
        output_dir: dir
      )
      expect(FileUtils).to receive(:mkdir_p).with(dir)
      new_sink(config)
    end
  end

  context 'filename generation' do
    config = Crawler::API::Config.new(
      domains: [{ url: 'https://example.com' }],
      output_sink: 'file'
    )
    let(:sink) { Crawler::OutputSink::File.new(config) }
    def create_crawl_result(url)
      url_obj = Crawler::Data::URL.parse(url)
      double('crawl_result', url: url_obj)
    end

    it 'removes slashes, spaces, and http/https/www prefixes' do
      test_cases = {
        'https://example.com/path/to/page/' => 'example_com_path_to_page',
        'https://www.test.com/some page.html/' => 'test_com_some_page_html',
        'https://sub.domain.com/path//double/slash/' => 'sub_domain_com_path_double_slash',
        'http://www.example.com' => 'example_com', # NOTE: the lack of trailing slash in the original URL
        'https://www.complex-url.com/path?param=value#fragment/' => 'complex-url_com_path_param_value_fragment'
      }

      test_cases.each do |input, expected|
        crawl_result = create_crawl_result(input)
        result = sink.generate_filename_from_url(crawl_result)

        expect(result).to eq(expected)
        expect(result).not_to include('/')
        expect(result).not_to include(' ')
        expect(result).not_to match(/^https?_/)
        expect(result).not_to match(/^www_/)
        expect(result).not_to end_with('_')
      end
    end
  end
end
