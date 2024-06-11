#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

class Errors
  # Raised when attempting to add a crawl result to the bulk queue, but it is currently flushing.
  # The bulk queue is single-threaded, but receives crawl results from multi-threaded processes.
  # This error is raised to prevent overloading the queue if Elasticsearch indexing is failing repeatedly
  #   and performing exponential backoff.
  # This error should be treated as retryable.
  class BulkQueueProcessingError < StandardError; end

  # Raised only if the queue item added somehow overflows the queue threshold.
  # The queue threshold is checked before an item is added so this error shouldn't occur.
  # If this error occurs, something is wrong with the interaction between the Elasticsearch sink and BulkQueue.
  class BulkQueueOverflowError < StandardError; end
end
