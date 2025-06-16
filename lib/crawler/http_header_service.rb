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
      JWT = 'jwt'
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

    JWT_AUTH_SCHEMA = {
      'type' => 'object',
      'required' => %w[domain type token],
      'additionalProperties' => false,
      'properties' => {
        'domain' => {
          'type' => 'string'
        },
        'type' => {
          'const' => AuthTypes::JWT
        },
        'token' => {
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
      'type' => 'object',
      'items' => {
        'oneOf' => [BASIC_AUTH_SCHEMA, RAW_HEADER_SCHEMA, JWT_AUTH_SCHEMA]
      }
    }.freeze

    def initialize(auth: nil)
      JSON::Validator.validate!(AUTH_SCHEMA, auth, validate_schema: true) if auth

      @auth = auth
    end

    def authorization_header_for_url(url)
      raise ArgumentError, 'Need a Crawler URL object!' unless url.is_a?(Crawler::Data::URL)

      return if @auth.nil?
      return unless @auth.fetch(:domain) == url.site

      value =
        case @auth.fetch(:type)
        when AuthTypes::BASIC
          "Basic #{Base64.strict_encode64("#{@auth.fetch(:username)}:#{@auth.fetch(:password)}")}"
        when AuthTypes::RAW
          @auth.fetch(:header)
        when AuthTypes::JWT
          "Bearer #{@auth.fetch(:jwt_token)}"
        end

      {
        type: @auth.fetch(:type),
        value:
      }
    end

    private

    attr_reader :auth
  end
end
