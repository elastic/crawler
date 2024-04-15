# frozen_string_literal: true

FactoryBot.define do
  factory :html_crawl_result, class: Crawler::Data::CrawlResult::HTML do
    url { 'http://example.com/' }
    status_code { 200 }
    content { 'Lorem ipsum' }

    initialize_with do
      new(
        url: Crawler::Data::URL.parse(url),
        status_code: status_code,
        content: content
      )
    end
  end

  factory :content_extractable_file_crawl_result, class: Crawler::Data::CrawlResult::ContentExtractableFile do
    url { 'http://example.com/test.pdf' }
    status_code { 200 }
    content { 'Lorem ipsum' }

    initialize_with do
      new(
        url: Crawler::Data::URL.parse(url),
        status_code: status_code,
        content: content
      )
    end
  end

  factory :robots_crawl_result, class: Crawler::Data::CrawlResult::RobotsTxt do
    url { 'http://example.com/robots.txt' }
    status_code { 200 }
    content { '' }

    initialize_with do
      new(
        url: Crawler::Data::URL.parse(url),
        status_code: status_code,
        content: content
      )
    end
  end

  factory :sitemap_crawl_result, class: Crawler::Data::CrawlResult::Sitemap do
    url { 'http://example.com/sitemap.xml' }
    status_code { 200 }
    content { '' }

    initialize_with do
      new(
        url: Crawler::Data::URL.parse(url),
        status_code: status_code,
        content: content
      )
    end
  end

  factory :redirect_crawl_result, class: Crawler::Data::CrawlResult::Redirect do
    url { 'http://example.com/' }
    status_code { 301 }
    location { 'http://example.com/new-location' }
    redirect_chain { [] }

    initialize_with do
      new(
        url: Crawler::Data::URL.parse(url),
        status_code: status_code,
        location: Crawler::Data::URL.parse(location),
        redirect_chain: redirect_chain
      )
    end
  end

  factory :error_crawl_result, class: Crawler::Data::CrawlResult::Error do
    url { 'http://example.com/' }
    status_code { 404 }
    error { 'Not found' }

    initialize_with do
      new(
        url: Crawler::Data::URL.parse(url),
        status_code: status_code,
        error: error
      )
    end
  end

  factory :not_found_crawl_result, class: Crawler::Data::CrawlResult::Error do
    url { 'http://example.com/' }
    status_code { 404 }
    error { 'Not found' }

    initialize_with do
      new(
        url: Crawler::Data::URL.parse(url),
        status_code: status_code,
        error: error
      )
    end
  end

  factory :transient_error_crawl_result, class: Crawler::Data::CrawlResult::Error do
    url { 'http://example.com/' }
    status_code { 500 }
    error { 'Transient Error' }

    initialize_with do
      new(
        url: Crawler::Data::URL.parse(url),
        status_code: status_code,
        error: error
      )
    end
  end
end
