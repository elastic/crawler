#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

require_dependency File.join(__dir__, '..', 'agent')
require_dependency File.join(__dir__, 'proto', 'well_known')

module Crawler
  module Agent
    # Thin bridge between plain Ruby hashes and protobuf messages of the Elastic Agent control
    # protocol. Messages are built dynamically from the checked-in descriptor set, so no
    # generated code is needed.
    module Proto
      DESCRIPTOR_SET = File.join(__dir__, 'proto', 'elastic-agent-client.textproto')
      MAIN_FILE = 'elastic-agent-client.proto'
      SERVICE_NAME = 'ElasticAgent'

      STRUCT_TYPE = 'google.protobuf.Struct'
      TIMESTAMP_TYPE = 'google.protobuf.Timestamp'

      # Imported descriptors that ship with protobuf-java
      WELL_KNOWN_FILES = {
        'google/protobuf/struct.proto' => -> { Java::ComGoogleProtobuf::Struct.getDescriptor.getFile },
        'google/protobuf/timestamp.proto' => -> { Java::ComGoogleProtobuf::Timestamp.getDescriptor.getFile }
      }.freeze

      # DynamicMessage requires exact Java boxed types per protobuf field type
      SCALAR_CONVERTERS = {
        'INT' => ->(value) { value.to_i.to_java(:int) },
        'LONG' => ->(value) { value.to_i.to_java(:long) },
        'FLOAT' => ->(value) { value.to_f.to_java(:float) },
        'DOUBLE' => ->(value) { value.to_f.to_java(:double) },
        'BOOLEAN' => ->(value) { value ? true : false },
        'STRING' => ->(value) { value.to_s },
        'BYTE_STRING' => ->(value) { Java::ComGoogleProtobuf::ByteString.copyFrom(value.to_s.b.to_java_bytes) }
      }.freeze

      class << self
        def message_type(name)
          file.findMessageTypeByName(name.to_s) ||
            raise(ArgumentError, "Unknown message type: #{name}")
        end

        def rpc(name)
          @rpcs ||= {}
          @rpcs[name.to_s] ||= build_rpc(name.to_s)
        end

        def build(name, attributes = {})
          build_message(message_type(name), attributes)
        end

        def decode(name, bytes)
          Java::ComGoogleProtobuf::DynamicMessage.parseFrom(message_type(name), bytes.to_s.b.to_java_bytes)
        end

        def encode(message)
          String.from_java_bytes(message.toByteArray)
        end

        def to_h(message)
          message.getDescriptorForType.getFields.each_with_object({}) do |field, hash|
            hash[field.getName.to_sym] = field_to_ruby(message, field)
          end
        end

        def file
          @file ||= load_files[MAIN_FILE]
        end

        private

        def load_files
          set = Java::ComGoogleProtobuf::DescriptorProtos::FileDescriptorSet.newBuilder
          Java::ComGoogleProtobuf::TextFormat.merge(File.read(DESCRIPTOR_SET), set)
          protos = set.getFileList.to_h { |proto| [proto.getName, proto] }
          built = {}
          protos.each_key { |name| build_file(name, protos, built) }
          built
        end

        def build_file(name, protos, built)
          built[name] ||= begin
            proto = protos.fetch(name)
            deps = proto.getDependencyList.map { |dep| WELL_KNOWN_FILES[dep]&.call || build_file(dep, protos, built) }
            Java::ComGoogleProtobuf::Descriptors::FileDescriptor.buildFrom(
              proto, deps.to_java(Java::ComGoogleProtobuf::Descriptors::FileDescriptor)
            )
          end
        end

        def build_rpc(name)
          service = file.findServiceByName(SERVICE_NAME)
          method = service.findMethodByName(name) || raise(ArgumentError, "Unknown rpc: #{name}")
          descriptor = Java::IoGrpc::MethodDescriptor
          descriptor.newBuilder
                    .setType(descriptor::MethodType::BIDI_STREAMING)
                    .setFullMethodName(descriptor.generateFullMethodName(service.getFullName, name))
                    .setRequestMarshaller(marshaller(method.getInputType))
                    .setResponseMarshaller(marshaller(method.getOutputType))
                    .build
        end

        def marshaller(type)
          Java::IoGrpcProtobuf::ProtoUtils.marshaller(Java::ComGoogleProtobuf::DynamicMessage.getDefaultInstance(type))
        end

        #-------------------------------------------------------------------------------------------
        # Ruby -> protobuf

        def build_message(type, attributes)
          return attributes if attributes.is_a?(Java::ComGoogleProtobuf::Message)

          builder = Java::ComGoogleProtobuf::DynamicMessage.newBuilder(type)
          attributes.each do |key, value|
            next if value.nil?

            set_field(builder, find_field(type, key), value)
          end
          builder.build
        end

        def find_field(type, name)
          type.findFieldByName(name.to_s) || raise(ArgumentError, "Unknown field #{name} for #{type.getFullName}")
        end

        def set_field(builder, field, value)
          if field.isMapField
            value.each { |k, v| builder.addRepeatedField(field, map_entry(field, k, v)) }
          elsif field.isRepeated
            Array(value).each { |v| builder.addRepeatedField(field, java_value(field, v)) }
          else
            builder.setField(field, java_value(field, value))
          end
        end

        def map_entry(field, key, value)
          entry_type = field.getMessageType
          key_field = entry_type.findFieldByName('key')
          value_field = entry_type.findFieldByName('value')
          Java::ComGoogleProtobuf::DynamicMessage.newBuilder(entry_type)
                                                 .setField(key_field, java_value(key_field, key))
                                                 .setField(value_field, java_value(value_field, value))
                                                 .build
        end

        def java_value(field, value)
          case field.getJavaType.name
          when 'ENUM' then enum_value(field, value)
          when 'MESSAGE' then message_value(field.getMessageType, value)
          else SCALAR_CONVERTERS.fetch(field.getJavaType.name).call(value)
          end
        end

        def enum_value(field, value)
          enum = field.getEnumType
          found = if value.is_a?(Integer)
                    enum.findValueByNumber(value)
                  else
                    enum.findValueByName(value.to_s) || enum.findValueByName(value.to_s.upcase)
                  end
          found || raise(ArgumentError, "Unknown value #{value.inspect} for enum #{enum.getFullName}")
        end

        def message_value(type, value)
          case type.getFullName
          when STRUCT_TYPE then WellKnown.struct_from_ruby(value)
          when TIMESTAMP_TYPE then WellKnown.timestamp_from_ruby(value)
          else build_message(type, value)
          end
        end

        #-------------------------------------------------------------------------------------------
        # protobuf -> Ruby

        def field_to_ruby(message, field)
          if field.isMapField
            message.getField(field).each_with_object({}) do |entry, hash|
              hash[map_entry_part(entry, 'key')] = map_entry_part(entry, 'value')
            end
          elsif field.isRepeated
            message.getField(field).map { |value| ruby_value(field, value) }
          elsif field.getJavaType.name == 'MESSAGE'
            message.hasField(field) ? ruby_value(field, message.getField(field)) : nil
          else
            ruby_value(field, message.getField(field))
          end
        end

        def map_entry_part(entry, part)
          field = entry.getDescriptorForType.findFieldByName(part)
          ruby_value(field, entry.getField(field))
        end

        def ruby_value(field, value)
          case field.getJavaType.name
          when 'ENUM' then value.getName.to_sym
          when 'BYTE_STRING' then String.from_java_bytes(value.toByteArray)
          when 'STRING' then value.to_s
          when 'MESSAGE' then message_to_ruby(value)
          else value
          end
        end

        def message_to_ruby(message)
          case message.getDescriptorForType.getFullName
          when STRUCT_TYPE then WellKnown.struct_to_ruby(message)
          when TIMESTAMP_TYPE then WellKnown.timestamp_to_ruby(message)
          else to_h(message)
          end
        end
      end
    end
  end
end
