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
      JSON::Validator.validate!(AUTH_SCHEMA, auth, validate_schema: true) if auth

      @auth = auth
    end

    def authorization_header_for_url(url)
      raise ArgumentError, 'Need a Crawler URL object!' unless url.is_a?(Crawler::Data::URL)

      match = auth&.find { |item| item.fetch('domain') == url.site }

      value =
        case match&.fetch('type')
        when AuthTypes::BASIC
          "Basic #{Base64.strict_encode64("#{match.fetch('username')}:#{match.fetch('password')}")}"
        when AuthTypes::RAW
          match.fetch('header')
        end

      return unless value

      {
        type: match&.fetch('type'),
        value: value
      }
    end

    private

    attr_reader :auth
  end
end
