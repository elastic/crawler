# frozen_string_literal: true

RSpec.describe(Crawler::API::Config) do
  let(:domains) { ['http://example.com'] }
  let(:normalized_domains) { ['http://example.com:80'] }

  let(:seed_urls) { ['http://example.com/'] }
  let(:output_dir) { '/tmp/crawler/example.com/123' }

  #-------------------------------------------------------------------------------------------------
  context 'constructor' do
    it 'should fail when provided with unknown options' do
      expect do
        Crawler::API::Config.new(fubar: 42)
      end.to raise_error(ArgumentError, /Unexpected configuration options.*fubar/)
    end

    #-----------------------------------------------------------------------------------------------
    it 'should use the console sink by default' do
      config = Crawler::API::Config.new(
        domain_allowlist: domains,
        seed_urls: seed_urls
      )
      expect(config.output_sink).to eq(:console)
    end

    #-----------------------------------------------------------------------------------------------
    it 'can define a crawl with console output' do
      config = Crawler::API::Config.new(
        domain_allowlist: domains,
        seed_urls: seed_urls,
        output_sink: :console
      )

      expect(config.domain_allowlist.map(&:to_s)).to eq(normalized_domains)
      expect(config.seed_urls.map(&:to_s).to_a).to eq(seed_urls)
      expect(config.output_sink).to eq(:console)
      expect(config.output_dir).to be_nil
    end

    #-----------------------------------------------------------------------------------------------
    it 'can define a crawl with file output' do
      config = Crawler::API::Config.new(
        domain_allowlist: domains,
        seed_urls: seed_urls,
        output_sink: :file,
        output_dir: output_dir
      )

      expect(config.domain_allowlist.map(&:to_s)).to eq(normalized_domains)
      expect(config.seed_urls.map(&:to_s).to_a).to eq(seed_urls)
      expect(config.output_sink).to eq(:file)
      expect(config.output_dir).to eq(output_dir)
    end
  end
end
