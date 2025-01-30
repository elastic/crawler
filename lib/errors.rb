#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

class Errors
  # Raised only if the queue item added somehow overflows the queue threshold.
  # The queue threshold is checked before an item is added so this error shouldn't occur.
  # If this error occurs, something is wrong with the interaction between the Elasticsearch sink and BulkQueue.
  class BulkQueueOverflowError < StandardError; end

  # Raised when attempting to add a crawl result to the sink, but it is currently locked.
  # This is specific for Elasticsearch sink. Basically the sink is single-threaded but
  # receives crawl results from multi-threaded processes. This error is raised to prevent
  # overloading the queue if Elasticsearch indexing is failing repeatedly and performing
  # exponential backoff. This error should be treated as retryable.
  class SinkLockedError < StandardError; end

  # Raised when there is a connection error to Elasticsearch. Specific for Elasticsearch sink.
  # During initialization of the Elasticsearch sink, it will attempt to make contact to
  # the host provided in the configuration. If contact cannot  be established, a system exit will occur.
  class ESConnectionError < SystemExit; end

  # Raised when the desired output index does not exist. This is specific for Elasticsearch
  # sink. During initialization of the Elasticsearch sink, it will call indices.exists()
  # against the output_index value, and will continue if the index is found.
  # If it is not found, this error will be raised, which causes a system exit to occur.
  class UnableToCreateIndex < SystemExit; end
end
