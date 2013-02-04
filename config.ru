require './app/main'
require 'sidekiq/web'

Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  username == ENV['SIDEKIQ_USER'] && password == ENV['SIDEKIQ_PASS']
end

run Rack::URLMap.new('/' => App, '/sidekiq' => Sidekiq::Web)
