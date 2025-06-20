#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require 'base64'
require 'json-schema'

module Crawler
  class HttpHeaderService
    module AuthTypes
      BASIC = 'basic'
      RAW = 'raw'
    end

    BASIC_AUTH_SCHEMA = {
      'type' => 'object',
      'required' => %w[domain type username password],
      'additionalProperties' => false,
      'properties' => {
        'domain' => {
          'type' => 'string'
        },
        'type' => {
          'const' => AuthTypes::BASIC
        },
        'username' => {
          'type' => 'string'
        },
        'password' => {
          'type' => 'string'
        }
      }
    }.freeze

    RAW_HEADER_SCHEMA = {
      'type' => 'object',
      'required' => %w[domain type header],
      'additionalProperties' => false,
      'properties' => {
        'domain' => {
          'type' => 'string'
        },
        'type' => {
          'const' => AuthTypes::RAW
        },
        'header' => {
          'type' => 'string'
        }
      }
    }.freeze

    AUTH_SCHEMA = {
      'type' => 'array',
      'items' => {
        'oneOf' => [BASIC_AUTH_SCHEMA, RAW_HEADER_SCHEMA]
      }
    }.freeze

    def initialize(auth: nil)
      JSON::Validator.validate!(AUTH_SCHEMA, auth, validate_schema: true)

      @auth = auth
    end

    def number_of_auth_headers
      # returns the number of configured auth headers, as we should keep the @auth attribute private
      @auth.nil? ? 0 : @auth.length
    end

    def authorization_header_for_url(url)
      raise ArgumentError, 'Need a Crawler URL object!' unless url.is_a?(Crawler::Data::URL)

      return if @auth.nil?

      complete_auth_header = nil
      @auth&.each do |auth_hashmap|
        next unless auth_hashmap.fetch(:domain) == url.site

        value =
          case auth_hashmap.fetch(:type)
          when AuthTypes::BASIC
            "Basic #{Base64.strict_encode64("#{auth_hashmap.fetch(:username)}:#{auth_hashmap.fetch(:password)}")}"
          when AuthTypes::RAW
            auth_hashmap.fetch(:header)
          end

        complete_auth_header = {
          type: auth_hashmap.fetch(:type),
          value:
        }
      end
      complete_auth_header
    end

    private

    attr_reader :auth
  end
end
