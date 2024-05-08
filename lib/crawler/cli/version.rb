require 'dry/cli'

module Crawler
  module CLI
    class Version < Dry::CLI::Command
      VERSION_PATH = File.expand_path('../../../product_version', __dir__).freeze

      desc 'Print version'

      def call(*)
        puts File.read(VERSION_PATH).strip
      end
    end
  end
end
