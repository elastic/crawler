# frozen_string_literal: true

RSpec.describe(Crawler::HttpClient::Response) do
  let(:url) { Crawler::Data::URL.parse('http://example.org/') }
  let(:response) do
    Crawler::HttpClient::Response.new(
      apache_response: apache_response,
      url: url,
      request_start_time: 1.second.ago,
      request_end_time: Time.now
    )
  end

  #-------------------------------------------------------------------------------------------------
  describe '#check_content_encoding' do
    let(:response_entity) { double(:response_entity, content_encoding: encoding) }
    let(:apache_response) { double(:apache_response, entity: response_entity) }

    def check_content_encoding
      response.send(:check_content_encoding)
    end

    context 'when given a supported content encoding' do
      let(:encoding) { 'gzip' }
      it 'should succeed' do
        expect { check_content_encoding }.to_not raise_error
      end
    end

    context 'when given a list of supported content encodings' do
      let(:encoding) { 'gzip,deflate' }
      it 'should succeed' do
        expect { check_content_encoding }.to_not raise_error
      end
    end

    context 'when given an unsupported content encoding' do
      let(:encoding) { 'banana' }
      it 'should fail' do
        expect { check_content_encoding }.to raise_error(Crawler::HttpClient::InvalidEncoding)
      end
    end

    context 'when given a list with an unsupported content encoding' do
      let(:encoding) { 'gzip,banana' }
      it 'should fail' do
        expect { check_content_encoding }.to raise_error(Crawler::HttpClient::InvalidEncoding)
      end
    end
  end
end
