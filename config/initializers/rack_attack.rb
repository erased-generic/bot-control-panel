class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle('req/ip', limit: 500, period: 1.minutes) do |req|
    req.ip
  end

  throttle('control_panel/token', limit: 500, period: 1.minute) do |req|
    req.params['token']
  end

  self.throttled_response = ->(env) {
    retry_after = (env['rack.attack.match_data'] || {})[:period]
    [
      429,
      { 'Content-Type' => 'application/json' },
      [{ error: "Too many requests. Retry after #{retry_after} seconds." }.to_json]
    ]
  }
end
