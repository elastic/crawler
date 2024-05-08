RSpec.describe(Crawler::CLI::Version) do
  describe '.call' do
    let(:version_path) { File.expand_path('../../../../../product_version', __FILE__) }

    it 'prints the current version from product_version_file' do
      expect(File).to receive(:read).with(version_path).and_return('1.0.0')
      expect { described_class.new.call }.to output("1.0.0\n").to_stdout
    end
  end
end
