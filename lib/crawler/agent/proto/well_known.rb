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

          # Messages parsed from the wire are DynamicMessages, so only reflection is used here
          def struct_to_ruby(struct)
            field(struct, 'fields').each_with_object({}) do |entry, hash|
              hash[field(entry, 'key').to_s] = value_to_ruby(field(entry, 'value'))
            end
          end

          def value_to_ruby(value)
            kind = value.getOneofFieldDescriptor(value.getDescriptorForType.getOneofs.first)
            return nil if kind.nil?

            case kind.getName
            when 'number_value' then number_to_ruby(value.getField(kind))
            when 'string_value' then value.getField(kind).to_s
            when 'bool_value' then value.getField(kind)
            when 'struct_value' then struct_to_ruby(value.getField(kind))
            when 'list_value' then field(value.getField(kind), 'values').map { |item| value_to_ruby(item) }
            end
          end

          def timestamp_to_ruby(timestamp)
            Time.at(field(timestamp, 'seconds'), field(timestamp, 'nanos'), :nsec)
          end

          def field(message, name)
            message.getField(message.getDescriptorForType.findFieldByName(name))
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
