#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License 2.0;
# you may not use this file except in compliance with the Elastic License 2.0.
#

# frozen_string_literal: true

FIXTURES_HOME = File.join(__dir__, '..', 'fixtures')

def fixture_file(*file_path)
  File.join(FIXTURES_HOME, *file_path)
end

def read_fixture(*file_path)
  File.read(fixture_file(*file_path))
end

def fixture_xml(*file_path)
  file_name = file_path.pop
  file_name = "#{file_name}.xml"
  read_fixture(*file_path, file_name)
end

def fixture_xml_gz(*file_path)
  file_name = file_path.pop
  file_name = "#{file_name}.xml.gz"
  read_fixture(*file_path, file_name)
end
