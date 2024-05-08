# load CLI dependencies
Dir[File.join(__dir__, 'cli/**/*.rb')].each { |f| require(f) }

module Crawler
  module CLI
    extend Dry::CLI::Registry

    register "version", Crawler::CLI::Version, aliases: ["v", "--version"]
  end
end
