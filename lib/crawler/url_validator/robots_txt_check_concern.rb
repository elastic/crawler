# frozen_string_literal: true

module Crawler
  module UrlValidator::RobotsTxtCheckConcern # rubocop:disable Style/ClassAndModuleChildren
    extend ActiveSupport::Concern

    def validate_robots_txt # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      # Fetch robots.txt using the standard Crawler HTTP executor
      crawl_result = http_executor.run(
        Crawler::Data::CrawlTask.new(
          url: url.join('/robots.txt'),
          type: :robots_txt,
          depth: 1
        ),
        follow_redirects: true
      )

      # Redirect errors are treated as a 404, but we could provide a slightly better message here
      if crawl_result.is_a?(Crawler::Data::CrawlResult::RedirectError)
        return validation_warn(:robots_txt, <<~MESSAGE)
          Our attempt at fetching a robots.txt file has failed with a redirect error: #{crawl_result.error}.
          The crawler will proceed as if the file does not exist for this domain.
        MESSAGE
      end

      # If there is no robots.txt, we are OK to proceed
      return validation_ok(:robots_txt, "No robots.txt found for #{url}.") if crawl_result.status_code == 404

      # HTTP 599 is a special code we use for internal errors
      if crawl_result.status_code == 599
        return validation_fail(:robots_txt, <<~MESSAGE)
          Failed to fetch robots.txt: #{crawl_result.error}.
          #{crawl_result.suggestion_message}
        MESSAGE
      end

      # If we could not fetch robots.txt because of a transient error, we could not proceed
      if crawl_result.status_code >= 500
        return validation_fail(:robots_txt, <<~MESSAGE)
          Transient error fetching robots.txt: HTTP #{crawl_result.status_code}.
          We could not proceed with crawling this site.
        MESSAGE
      end

      # Register robots.txt results and check if we have access to the home page
      robots_txt = Crawler::RobotsTxtService.new(user_agent: crawler_api_config.user_agent)
      robots_txt.register_crawl_result(url.domain, crawl_result)

      if robots_txt.parser_for_domain(url.domain).allow_all?
        validation_ok(:robots_txt, 'Found a robots.txt and it allows us full access to the domain.')
      else
        robots_outcome = robots_txt.url_disallowed_outcome(url)

        # Format the results based on the rules discovered
        if robots_outcome.allowed?
          validation_warn(:robots_txt, <<~MESSAGE)
            Found a robots.txt file at #{crawl_result.url} and it allows us access to the domain with some restrictions
            that may affect content indexing.
          MESSAGE
        else
          validation_fail(:robots_txt, <<~MESSAGE)
            Found a robots.txt file at #{crawl_result.url} and it disallows us access to the domain:
            #{robots_outcome.disallow_message}.
          MESSAGE
        end
      end
    end
  end
end
