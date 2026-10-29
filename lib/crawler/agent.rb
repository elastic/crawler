#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

# Runs the crawler as an Elastic Agent component, speaking the Elastic Agent V2 control
# protocol (gRPC over mTLS). Connection details are handed over by Agent on STDIN, the
# crawl configuration arrives through the policy's input/output units and crawls are
# triggered either by the configured schedule or by Agent actions.
module Crawler
  module Agent
    class Error < StandardError; end

    # Raised by action handlers to reject an action with a message that is sent back to Agent
    class ActionError < Error; end
  end
end
