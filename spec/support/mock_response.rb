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
