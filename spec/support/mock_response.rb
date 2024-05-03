#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

class MockResponse < OpenStruct
  def equal_for_specified_keys?(response)
    to_h.all? do |key, val|
      val.to_s == response.send(key).to_s
    end
  end
end

def mock_response(args)
  MockResponse.new(args)
end
