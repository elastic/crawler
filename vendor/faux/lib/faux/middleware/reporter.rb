#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

module Faux
  module Middleware

    # Rack middleware to intercept requests and increments a counter based on
    # the request path. If the path is '/status', we'll return a JSON report
    # of the request counts since the application has been running.
    class Reporter

      def self.counter
        @counter ||= Hash.new(0)
      end

      def self.reset!
        @counter = Hash.new(0)
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        if env['PATH_INFO'] == '/status'
          [200, { 'Content-Type' => 'application/json' }, [ Reporter.counter.to_json ]]
        else
          Reporter.counter[env['PATH_INFO']] += 1
          @app.call(env)
        end
      end

    end
  end
end
