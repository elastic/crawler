module Faux
  module Helpers
    module Url
      def absolute_url_for(path)
        "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{path}"
      end
    end
  end
end
