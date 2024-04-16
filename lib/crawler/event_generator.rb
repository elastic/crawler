# frozen_string_literal: true

require 'bson'
require 'socket'
require 'logger'

# rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
module Crawler
  class EventGenerator # rubocop:disable Metrics/ClassLength
    attr_reader :config

    delegate :system_logger, to: :config

    def initialize(config)
      @config = config

      # Initialize it with an old timestamp to make sure we log stats ASAP after initialization
      @last_stats_dump = Concurrent::AtomicReference.new(Time.at(0))
    end

    #-----------------------------------------------------------------------------------------------
    # Returns the timestamp of the last crawl_status event
    def last_stats_dump
      @last_stats_dump.value
    end

    # Outputs a bunch of stats about the running crawl into the event log to help with monitoring
    def log_crawl_status(crawl, force: false)
      time_since_last_dump = Time.now - last_stats_dump
      return if time_since_last_dump < config.stats_dump_interval && !force

      @last_stats_dump.set(Time.now)
      crawl_status(crawl)
    end

    #-----------------------------------------------------------------------------------------------
    def log_error(error, message)
      full_message = "#{message}: #{error.class}: #{error.message}"
      system_logger.error("Crawl Error: #{full_message}")
      log_event(
        'event.type' => 'error',
        'error.message' => full_message,
        'error.stack_trace' => error.backtrace&.join("\n")
      )
    end

    #-----------------------------------------------------------------------------------------------
    # Crawl Lifecycle Events
    #-----------------------------------------------------------------------------------------------
    def crawl_start(url_queue_items:, seen_urls:)
      resume = (url_queue_items + seen_urls).positive?
      action =
        if resume
          "Resuming a crawl (#{url_queue_items} pending URLs and #{seen_urls} seen URLs)"
        else
          'Starting a crawl'
        end
      system_logger.info("#{action} with the following configuration: #{config}")

      log_crawl_event(
        'event.type' => 'start',
        'event.action' => 'crawl-start',
        'crawler.crawl.config' => config.to_s,
        'crawler.crawl.resume' => resume
      )
    end

    def crawl_end(outcome:, message:, resume_possible:)
      system_logger.info("Finished a crawl. Result: #{outcome}: #{message}")
      log_crawl_event(
        'event.type' => 'end',
        'event.action' => 'crawl-end',
        'event.outcome' => outcome,
        'crawler.crawl.resume_possible' => resume_possible,
        'message' => message
      )
    end

    def crawl_seed(seed_urls_count, type:)
      log_crawl_event(
        'event.type' => 'change',
        'event.action' => 'crawl-seed',
        'crawler.crawl.seed_urls.count' => seed_urls_count,
        'crawler.url.type' => type.to_s
      )
    end

    #-----------------------------------------------------------------------------------------------
    def crawl_status(crawl)
      status = crawl.status
      system_logger.info(crawl_status_for_system_log(status))

      log_crawl_metric(
        prefixed_ecs_event(status, 'crawler.status').merge(
          'event.type' => 'info',
          'event.action' => 'crawl-status'
        )
      )
    end

    # Returns an ECS-formatted event based on a given hash and a field prefix for all fields
    def prefixed_ecs_event(fields, prefix)
      {}.tap do |event|
        fields.each do |k, v|
          event_field = "#{prefix}.#{k}"
          if v.is_a?(Hash)
            event.merge!(prefixed_ecs_event(v, event_field))
          else
            event[event_field] = v
          end
        end
      end
    end

    # Formats a crawl_status event for free text logging
    def crawl_status_for_system_log(status)
      "Crawl status: #{status.map { |kv| kv.join('=') }.join(', ')}"
    end

    #-----------------------------------------------------------------------------------------------
    # URL Life-cycle Events
    #-----------------------------------------------------------------------------------------------
    def url_seed(url:, source_url:, type:, crawl_depth:, source_type:)
      system_logger.info(
        "Added a new URL to the crawl queue: '#{url}' (type: #{type}, source: #{source_type}, depth: #{crawl_depth})"
      )
      log_url_event(
        url,
        'event.type' => 'start',
        'event.action' => 'url-seed',
        'crawler.url.type' => type.to_s,
        'crawler.url.source_type' => source_type.to_s,
        'crawler.url.source_url.hash' => source_url&.normalized_hash,
        'crawler.url.source_url.full' => source_url&.to_s,
        'crawler.url.crawl_depth' => crawl_depth
      )
    end

    #-----------------------------------------------------------------------------------------------
    def url_fetch(url:, crawl_result:, auth_type: nil) # rubocop:disable Metrics/AbcSize
      status_code = crawl_result.status_code
      outcome = outcome_from_status_code(status_code)
      system_logger.info("Fetched a page '#{url}' with a status code #{status_code} and an outcome of '#{outcome}'")

      event = {
        'crawler.url.auth.type' => auth_type,
        'event.type' => 'access',
        'event.action' => 'url-fetch',
        'event.outcome' => outcome,
        'event.start' => crawl_result.start_time,
        'event.end' => crawl_result.end_time,
        'event.duration' => crawl_result.duration,
        'http.request.method' => 'get',
        'http.response.status_code' => status_code.to_s
      }

      if crawl_result.error?
        event['message'] = crawl_result.error
      elsif crawl_result.success?
        event['http.response.body.bytes'] = crawl_result.content.bytesize
      elsif crawl_result.redirect?
        event['crawler.url.redirect.location'] = crawl_result.location.to_s
        event['crawler.url.redirect.chain'] = crawl_result.redirect_chain.map(&:to_s)
        event['crawler.url.redirect.count'] = crawl_result.redirect_count
      end

      log_url_event(url, event)
    end

    def outcome_from_status_code(code)
      return :success if code >= 200 && code <= 299
      return :failure if code >= 300 && code <= 599

      :unknown
    end

    #-----------------------------------------------------------------------------------------------
    def url_discover(url:, source_url:, crawl_depth:, type:, deny_reason: nil, message: nil)
      log_url_event(
        url,
        'event.type' => type,
        'event.action' => 'url-discover',
        'crawler.url.deny_reason' => deny_reason,
        'crawler.url.crawl_depth' => crawl_depth,
        'crawler.url.source_url.hash' => source_url&.normalized_hash,
        'crawler.url.source_url.full' => source_url&.to_s,
        'message' => message
      )
    end

    def url_discover_denied(args)
      raise ArgumentError, 'Need a deny reason' unless args.include?(:deny_reason)

      url_discover(args.merge(type: :denied))
    end

    #-----------------------------------------------------------------------------------------------
    def url_extracted(url:, type:, outcome:, start_time:, end_time:, duration:, message: nil, deny_reason: nil)
      log_url_event(
        url,
        'event.type' => type,
        'event.action' => 'url-extracted',
        'event.module' => 'html',
        'event.outcome' => outcome,
        'event.start' => start_time,
        'event.end' => end_time,
        'event.duration' => duration,
        'crawler.url.deny_reason' => deny_reason,
        'message' => message
      )
    end

    #-----------------------------------------------------------------------------------------------
    def url_output(url:, sink_name:, outcome:, start_time:, end_time:, duration:, message:, output: nil)
      system_logger_severity = outcome.to_s == 'success' ? Logger::INFO : Logger::WARN
      system_logger.add(
        system_logger_severity,
        "Processed crawl results from the page '#{url}' via the #{sink_name} output. " \
        "Outcome: #{outcome}. Message: #{message}."
      )

      event = {
        'event.type' => 'info',
        'event.action' => 'url-output',
        'event.module' => sink_name,
        'event.outcome' => outcome,
        'event.start' => start_time,
        'event.end' => end_time,
        'event.duration' => duration,
        'message' => message
      }

      output&.fetch(sink_name)&.each do |key, value|
        event["crawler.output.#{sink_name}.#{key}"] = value
      end

      log_url_event(url, event)
    end

    #-----------------------------------------------------------------------------------------------
    def url_reprocessed(url:, sink_name:, outcome:, message:, type:, output: nil)
      event = {
        'event.type' => type,
        'event.action' => 'url-reprocessed',
        'event.module' => sink_name,
        'event.outcome' => outcome,
        'message' => message
      }

      output&.fetch(sink_name)&.each do |key, value|
        event["crawler.output.#{sink_name}.#{key}"] = value
      end

      log_url_event(url, event)
    end

    private

    def static_ecs_common_fields
      @static_ecs_common_fields ||= {
        'service.ephemeral_id' => Crawler.service_id,
        'service.type' => 'crawler',
        'service.version' => Crawler.version,
        'process.pid' => Process.pid,
        'host.name' => Socket.gethostname
      }
    end

    def ecs_common_fields
      static_ecs_common_fields.merge(
        '@timestamp' => Time.now.utc.iso8601,
        'event.id' => BSON::ObjectId.new.to_s,
        'process.thread.id' => Thread.current.object_id
      )
    end

    def url_fields(url)
      {
        # ECS fields
        'url.full' => url.to_s,
        'url.scheme' => url.scheme,
        'url.domain' => url.host,
        'url.path' => url.path,
        'url.query' => url.query,
        'url.fragment' => url.fragment,
        'url.username' => url.user,
        'url.password' => url.password,
        # Custom fields
        'crawler.url.hash' => url.normalized_hash
      }
    end

    def static_crawl_fields
      @static_crawl_fields ||= {
        'crawler.crawl.id' => config.crawl_id,
        'crawler.crawl.stage' => config.crawl_stage
      }
    end

    #-----------------------------------------------------------------------------------------------
    def log_url_event(url, fields)
      log_crawl_event(url_fields(url).merge(fields))
    end

    def log_crawl_event(fields)
      log_event(static_crawl_fields.merge(fields))
    end

    def log_crawl_metric(fields)
      log_metric(static_crawl_fields.merge(fields))
    end

    # TODO: log ingestion event

    #-----------------------------------------------------------------------------------------------
    def log_event(event_info)
      log(event_info.merge('event.kind' => 'event'))
    end

    def log_metric(event_info)
      log(event_info.merge('event.kind' => 'metric'))
    end

    #-----------------------------------------------------------------------------------------------
    def log(event_info) # rubocop:disable Metrics/AbcSize
      final_event = ecs_common_fields.merge(event_info).compact

      # event.start and event.end can be passed as Time objects, but need to be UTC ISO 8601 strings.
      final_event['event.start'] = final_event['event.start'].utc.iso8601 if final_event['event.start'].is_a?(Time)

      final_event['event.end'] = final_event['event.end'].utc.iso8601 if final_event['event.end'].is_a?(Time)

      # Convert duration into nanoseconds
      if final_event.key?('event.duration')
        final_event['event.duration'] = duration_to_nanoseconds(final_event['event.duration'])
      end

      config.output_event(final_event)
    end

    #-----------------------------------------------------------------------------------------------
    # Receives a duration value and converts it into nanoseconds
    def duration_to_nanoseconds(duration)
      duration = duration.real if duration.is_a?(Benchmark::Tms)
      (duration * 1e9).to_i
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/ParameterLists
