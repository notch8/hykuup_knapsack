# frozen_string_literal: true
# OVERRIDE Hyku (samvera/hyku@ddd0c4c785c28a08cbbd0e12ac1d092f0ec4d4d8) - fix
# broken redis session namespacing.
#
# The upstream initializer passes `url: session_url` to `config.session_store
# :redis_store`, but neither ActionDispatch::Session::RedisStore#initialize
# nor Redis::Rack::Connection#store ever read `:url` - only `:redis_server`
# (or `:servers`, mapped from `:redis_server`). Because of that, the intended
# "/session" namespace segment on session_url is silently dropped: the
# connection falls back to Redis::Store::Factory.create(nil) -> Redis::Store.new({})
# -> the redis gem's own ENV['REDIS_URL'] fallback, so sessions land in the
# right redis instance but with NO namespace - indistinguishable from other
# keys sharing the same db (this took down main.hykuup.com when that shared
# redis OOM'd). Passing `redis_server:` instead routes through
# Redis::Store::Factory's URL parsing, which does split the
# "/session" path segment into a real namespace, restoring "session:*" keys.
#
# Remove when: fixed upstream in samvera/hyku.
redis_url = ENV.fetch('REDIS_URL', false)
if redis_url
  session_url = "#{redis_url}/session"
  secure = Rails.env.production? || Rails.env&.staging?
  key = Rails.env.production? ? "_hyku_session" : "_hyku_session_#{Rails.env}"

  Rails.application.config.session_store :redis_store,
    redis_server: session_url,
    expire_after: 1.day,
    key:,
    threadsafe: true,
    secure:,
    same_site: :lax,
    httponly: true
else
  Rails.application.config.session_store :cookie_store, key: '_hyku_session'
end
