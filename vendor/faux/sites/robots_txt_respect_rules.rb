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
