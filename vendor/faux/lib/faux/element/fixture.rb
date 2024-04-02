module Faux
  module Element
    class Fixture < Base

      attr_reader :fixture_content

      def call(env)
        @fixture_content = nil
        super
      end

      def response_body
        [ @fixture_content ]
      end

      def path(fixture_file_path)
        begin
          full_path = File.join(Dir.pwd, fixture_file_path)
          file = File.open(full_path)
        rescue => e
message = <<-EOL
Please provide correct path to fixture:

  example: `path: 'fixture/simple.html'`

  error: #{e} #{e.message}
  backtrace: #{e.backtrace}
EOL
raise ArgumentError, message
        end
        @fixture_content = file.read
      end
    end
  end
end
