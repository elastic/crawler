#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

module Crawler
  module Data
    module UrlQueue
      class Error < StandardError; end

      class TransientError < Error; end

      class QueueFullError < TransientError; end

      def self.create(config)
        queue_type = config.url_queue.to_s
        queue_class_for_type(queue_type).new(config)
      end

      def self.queue_class_for_type(queue_type)
        queue_class_name = "Crawler::Data::UrlQueue::#{queue_type.classify}"
        queue_class_name.safe_constantize.tap do |queue_class|
          raise ArgumentError, "Unknown URL queue type: #{queue_type}" unless queue_class
        end
      end
    end
  end
end
