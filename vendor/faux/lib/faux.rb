#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

require 'active_support'
require 'json'
require 'rack/mount'
require 'rack'

require_relative 'site'
require_relative 'faux/helpers/url'
require_relative 'faux/element/base'
require_relative 'faux/element/atom_feed'
require_relative 'faux/element/fixture'
require_relative 'faux/element/page'
require_relative 'faux/element/sitemap'
require_relative 'faux/element/robots'
require_relative 'faux/element/path_with_content_length'
require_relative 'faux/middleware/reporter'
require_relative 'faux/version'

module Faux
  def self.site(&block)
    Class.new(Faux::Base) do
      instance_eval(&block) if block
    end
  end
end

module Faux
  class Base
    class << self
      attr_reader :route_set

      def call(env)
        route_set.freeze.call(env)
      end

      def route_set
        @route_set ||= Rack::Mount::RouteSet.new
      end

      def route(method, path_info, element, options={}, &block)
        route_set.add_route(build_endpoint(element, options, &block), :request_method => method, :path_info => path_info)
      end

      def build_endpoint(element, options, &block)
        builder = Rack::Builder.new
        builder.use Rack::CommonLogger
        builder.use Faux::Middleware::Reporter
        builder.run "Faux::Element::#{element}".constantize.new(options, &block)
        builder.to_app
      end

      def atom_feed(path_info, &block)
        route('GET', path_info, 'AtomFeed', &block)
      end

      def page(path_info, &block)
        route('GET', path_info, 'Page', &block)
      end

      def sitemap(path_info, &block)
        route('GET', path_info, 'Sitemap', &block)
      end

      def sitemap_index(path_info, &block)
        route('GET', path_info, 'Sitemap', { :index => true }, &block)
      end

      def sitemap_gz(path_info, &block)
        route('GET', path_info, 'Sitemap', { :gzip => true }, &block)
      end

      def robots(path_info = '/robots.txt', &block)
        route('GET', path_info, 'Robots', &block)
      end

      def path_with_content_length(path_info, size=nil)
        route('GET', path_info, 'PathWithContentLength', { :size => size })
      end

      def fixture(path_info, &block)
        route('GET', path_info, 'Fixture', &block)
      end

      # Guarantees the '/status' route exists on all Faux applications.
      def inherited(klass)
        @sites ||= []
        @sites << klass
        klass.page '/status'
      end
    end
  end
end
