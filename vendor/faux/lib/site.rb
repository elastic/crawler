#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#

# frozen_string_literal: true

require 'rack'
require 'webrick'
require 'webrick/https'

module Faux
  # Class to manage creation and destruction of mounted Rack instances
  class Site
    attr_reader :site, :options, :server, :server_thread

    def initialize(site, options = {})
      @site = site
      @options = options
      start if options.fetch(:start, true)
    end

    def start
      if options[:debug]
        puts "Faux: INFO: Starting Faux for #{site} (#{options.inspect})"
      end

      start_queue = Queue.new
      rack_opts = {
        :app => site,
        :Port => options[:port] || 9393,
        :server => :webrick,
        :StartCallback => proc { start_queue << :start }
      }

      if options[:ssl]
        key = OpenSSL::PKey::RSA.new(File.read(options.fetch(:ssl_key)))
        cert = OpenSSL::X509::Certificate.new(File.read(options.fetch(:ssl_certificate)))
        rack_opts.merge!(
          :SSLEnable => true,
          :SSLPrivateKey => key,
          :SSLCertificate => cert,
          :SSLCACertificateFile => options[:ssl_ca_certificate]
        )
      end

      @server ||= Rack::Server.new(rack_opts)
      @server_thread = Thread.new { server.start }
      start_queue.pop
    end

    def stop
      # Stop Webrick
      server.server.shutdown

      # Make sure the thread has stopped or kill it within a second
      10.times do
        break unless server_thread.alive?
        sleep(0.1)
      end
      server_thread.kill

      # Reset the state of the site
      @server_thread = nil
      @server = nil
    end
  end
end
