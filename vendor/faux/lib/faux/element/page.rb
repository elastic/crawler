#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

module Faux
  module Element
    class Page < Base

      attr_reader :canonical, :links, :meta_robots_rules, :base_url

      def call(env)
        @body_content = []
        @head_content = []
        @head_html = ''
        @body_html = ''
        super
      end

      def response_body
        [ '<html>%s%s</html>' % [ @head_html, @body_html ] ]
      end

      def head(&block)
        @head_html = begin
          block.call
          '<head>%s</head>' % @head_content.join("\n")
        end
      end

      def body(&block)
        @body_html = begin
          block.call
          '<body>%s</body>' % @body_content.join("\n")
        end
      end

      def text(&block)
        @body_content << block.call.to_s
      end

      private

      def canonical_to(url_or_path)
        @head_content << %Q(<link rel="canonical" href="#{url_or_path}")
      end

      def robots(rule)
        @head_content << %Q(<meta name="robots" content="#{rule}">)
      end

      def atom_to(path)
        @head_content << %Q(<link rel="alternate" type="application/atom+xml" href="#{path}" />)
      end

      def base(url_or_path)
        @head_content << %Q(<base href="#{url_or_path}">)
      end

      def link_to(url_or_path, options = {})
        relative = options.delete(:relative)
        url_or_path = absolute_url_for(url_or_path) if relative == false

        attributes = [''] + options.map { |k,v| "#{k}='#{v}'"}
        @body_content << %Q(<a href="#{url_or_path}"#{attributes.join(' ')}>#{url_or_path}</a>)
      end
    end
  end
end
