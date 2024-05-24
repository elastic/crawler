#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the MIT License;
# see LICENSE file in the project root for details
#
class RobotsTxtRespectRules < Faux::Base
  page '/' do
    body do
      link_to '/bar'
      link_to '/foo'
    end
  end

  page '/bar'
  page '/foo'

  robots do
    user_agent '*'
    disallow '/foo'
  end
end
