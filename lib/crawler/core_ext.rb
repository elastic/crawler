#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

#
# This file contains useful extensions for core classes
#
class Time
  # Returns the number of seconds since the system boot
  #
  # This method is useful for calculating elapsed time or difference between
  # two events without having to worry about daylight savings, leap seconds, etc.
  #
  def self.monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
