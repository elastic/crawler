#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module OutputSink
    def self.create(config)
      sink_type = config.output_sink.to_s
      sink_class_for_type(sink_type).new(config)
    end

    def self.sink_class_for_type(sink_type)
      sink_class_name = "::Crawler::OutputSink::#{sink_type.classify}"
      sink_class_name.safe_constantize.tap do |sink_class|
        raise ArgumentError, "Unknown output sink: #{sink_type.inspect}" unless sink_class
      end
    end
  end
end
