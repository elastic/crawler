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
        unless sink_class
          raise ArgumentError, "Unknown output sink: #{sink_type.inspect}"
        end
      end
    end
  end
end
