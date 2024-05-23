#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

module Faux
  module Helpers
    module Url
      def absolute_url_for(path)
        "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{path}"
      end
    end
  end
end
