# frozen_string_literal: true
#
# Compares an Array of Crawler::Data::CrawlResult with expected results (Array of MockResponse)
# Each field specified in the expected results MockResponse is going to be compared
# to the field on CrawlerResponse. If all of the specified fields are equal to
# their counterparts on the response, the result is equal.
RSpec::Matchers.define :have_these_results do |expected_results|
  match do |results|
    expected_results.map do |expected_response|
      results.detect { |result| expected_response.equal_for_specified_keys?(result) }
    end.all?
  end
  failure_message do |results|
    failure_message_template(results, expected_results)
  end
end

# Same as `have_these_results` but also ensures that overall number of results
# is the same for both collections.
RSpec::Matchers.define :have_only_these_results do |expected_results|
  match do |results|
    return false if expected_results.size != results.size

    # Check to make sure all of the results we expected have been reported as crawled
    expect(results).to have_these_results(expected_results)
  end
  failure_message do |results|
    failure_message_template(results, expected_results)
  end
end

#---------------------------------------------------------------------------------------------------
def failure_message_template(results, expected_results)
  missing = []
  extra = results.map(&:clone)

  expected_results.each do |expected_result|
    result_index = extra.index { |result| expected_result.equal_for_specified_keys?(result) }

    if result_index
      extra.delete_at(result_index)
    else
      missing << expected_result
    end
  end

  out = +''

  if missing.present?
    out << "MISSING #{missing.length} result(s):\n"
    missing.each_with_index { |m, i| out << "    #{i}: #{m}\n" }
  end

  if extra.present?
    out << "#{extra.length} EXTRA result(s):\n"
    extra.each_with_index { |e, i| out << "    #{i}: #{e}\n" }
  end

  out << "\n\n"
  out << "Actual results:\n"
  results.each_with_index { |r, i| out << "    #{i}: #{r}\n" }
  out << "Expected results:\n"
  expected_results.each_with_index { |e, i| out << "    #{i}: #{e}\n" }

  out
end
