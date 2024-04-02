require 'active_support/core_ext/numeric'

module Faux
  module Element

    # This element is used primarily in testing against pages of given size.
    # Do NOT add functionality to this file to cater to other cases, use
    # `page` element instead.
    class PathWithContentLength < Base
      attr_reader :size

      def call(env)
        @size = options[:size]
        super
      end

      def response_body
        content = 'a' * (size || 0)
        [content]
      end
    end
  end
end
