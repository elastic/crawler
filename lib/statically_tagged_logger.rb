#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

#
# A thin proxy for wrapping loggers with ActiveSupport::TaggedLogging using
# a statically defined set of tags.
#
class StaticallyTaggedLogger
  attr_reader :parent_logger, :tags

  def initialize(parent_logger, *tags)
    @parent_logger = coerce_to_tagged_logger(parent_logger)
    @tags = [*tags].flatten.compact.uniq
  end

  #-------------------------------------------------------------------------------------------------
  # Behaves like `ActiveSupport::TaggedLogging#tagged`, but with one important difference:
  # If called without a block, it returns a proxy object with the tags statically applied.
  #
  # This means, that one could call `some_logger.tagged(:foo)` and use the returned value
  # as a new logger with the tags applied to all subsequent logging calls.
  #
  def tagged(*tags, &block)
    return StaticallyTaggedLogger.new(self, *tags) unless block

    parent_logger.tagged(*tags, &block)
  end

  #-------------------------------------------------------------------------------------------------
  # Proxy all calls to the parent object, behaving like a proxy
  def method_missing(meth, ...)
    parent_logger.tagged(*tags) do
      parent_logger.public_send(meth, ...)
    end
  end

  def respond_to_missing?(method_name, include_private)
    parent_logger.respond_to?(method_name, include_private)
  end

  private

  def coerce_to_tagged_logger(logger)
    if logger.is_a?(StaticallyTaggedLogger) || logger.is_a?(ActiveSupport::TaggedLogging)
      logger
    else
      ActiveSupport::TaggedLogging.new(logger)
    end
  end
end
