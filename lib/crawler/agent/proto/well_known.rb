#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Agent
    module Proto
      # Conversions between Ruby objects and the protobuf well-known types used by the protocol
      module WellKnown
        class << self
          def struct_from_ruby(hash)
            return hash if hash.is_a?(Java::ComGoogleProtobuf::Struct)

            builder = Java::ComGoogleProtobuf::Struct.newBuilder
            hash.each { |key, value| builder.putFields(key.to_s, value_from_ruby(value)) }
            builder.build
          end

          def value_from_ruby(value)
            builder = Java::ComGoogleProtobuf::Value.newBuilder
            case value
            when nil then builder.setNullValue(Java::ComGoogleProtobuf::NullValue::NULL_VALUE)
            when true, false then builder.setBoolValue(value)
            when Numeric then builder.setNumberValue(value.to_f)
            when Hash then builder.setStructValue(struct_from_ruby(value))
            when Array then builder.setListValue(list_from_ruby(value))
            else builder.setStringValue(value.to_s)
            end
            builder.build
          end

          def list_from_ruby(array)
            list = Java::ComGoogleProtobuf::ListValue.newBuilder
            array.each { |item| list.addValues(value_from_ruby(item)) }
            list
          end

          def timestamp_from_ruby(time)
            return time if time.is_a?(Java::ComGoogleProtobuf::Timestamp)

            time = Time.at(time) unless time.is_a?(Time)
            Java::ComGoogleProtobuf::Timestamp.newBuilder.setSeconds(time.to_i).setNanos(time.nsec).build
          end

          def struct_to_ruby(struct)
            struct.getFieldsMap.each_with_object({}) { |(key, value), hash| hash[key.to_s] = value_to_ruby(value) }
          end

          def value_to_ruby(value)
            case value.getKindCase.name
            when 'NUMBER_VALUE' then number_to_ruby(value.getNumberValue)
            when 'STRING_VALUE' then value.getStringValue.to_s
            when 'BOOL_VALUE' then value.getBoolValue
            when 'STRUCT_VALUE' then struct_to_ruby(value.getStructValue)
            when 'LIST_VALUE' then value.getListValue.getValuesList.map { |item| value_to_ruby(item) }
            end
          end

          def timestamp_to_ruby(timestamp)
            Time.at(timestamp.getSeconds, timestamp.getNanos, :nsec)
          end

          # Struct numbers are always doubles; whole numbers are turned back into integers so that
          # configuration values such as limits and ports keep their expected Ruby types
          def number_to_ruby(number)
            number == number.floor && number.abs < (2**53) ? number.to_i : number
          end
        end
      end
    end
  end
end
