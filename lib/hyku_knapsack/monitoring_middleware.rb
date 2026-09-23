# frozen_string_literal: true

require 'json'
require 'rack/utils'

module HykuKnapsack
  # Rack middleware that exposes Puma's runtime stats as JSON for external
  # monitoring (Site24x7 polls this to alert on thread-pool exhaustion before
  # it becomes user-facing downtime).
  #
  # Inserted at the very front of the middleware stack (see engine.rb) so the
  # response never touches the database, Redis, or tenant resolution — if Puma
  # can serve anything at all, it can serve this.
  #
  # GET /monitoring/puma_stats
  #   In single-mode Puma (how this app runs, see bin/web) the payload looks
  #   like:
  #     { "started_at": "...", "backlog": 0, "running": 7, "pool_capacity": 5,
  #       "max_threads": 7, "requests_count": 12345 }
  #   pool_capacity is the number of additional requests this process could
  #   accept right now (0 = saturated); backlog is requests accepted but not
  #   yet assigned a thread.
  #
  # Access is open by default. Set MONITORING_TOKEN to require
  # `Authorization: Bearer <token>` (or a `?token=` query param, which some
  # monitoring products are easier to configure with).
  class MonitoringMiddleware
    PUMA_STATS_PATH = '/monitoring/puma_stats'

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env['PATH_INFO'] == PUMA_STATS_PATH
      return respond(405, 'error' => 'method not allowed') unless env['REQUEST_METHOD'] == 'GET'
      return respond(401, 'error' => 'unauthorized') unless authorized?(env)

      stats = puma_stats
      return respond(503, 'error' => 'puma stats unavailable') unless stats

      respond(200, stats)
    end

    private

    def respond(status, body)
      json = JSON.generate(body)
      [status, { 'Content-Type' => 'application/json', 'Content-Length' => json.bytesize.to_s }, [json]]
    end

    def authorized?(env)
      expected = ENV['MONITORING_TOKEN']
      return true if expected.blank?

      provided = bearer_token(env) || Rack::Utils.parse_query(env['QUERY_STRING'].to_s)['token']
      return false unless provided.is_a?(String) && provided.bytesize == expected.bytesize

      Rack::Utils.secure_compare(expected, provided)
    end

    def bearer_token(env)
      header = env['HTTP_AUTHORIZATION'].to_s
      header.start_with?('Bearer ') ? header.delete_prefix('Bearer ') : nil
    end

    # Puma.stats_hash is only usable once the Puma launcher has registered its
    # stats object (i.e. the app is actually being served by Puma). Under other
    # entry points (rake, console) it raises NoMethodError on the nil stats
    # object, which we translate into a 503.
    def puma_stats
      return nil unless defined?(Puma) && Puma.respond_to?(:stats_hash)

      Puma.stats_hash
    rescue NoMethodError
      nil
    end
  end
end
