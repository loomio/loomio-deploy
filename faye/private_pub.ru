# Run with: rackup private_pub.ru -s thin -E production
require "bundler/setup"
require "yaml"
require "faye"
require "private_pub"

if ENV['ERRBIT_KEY']
  require 'airbrake'
  Airbrake.configure do |config|
    config.api_key = ENV["ERRBIT_KEY"]
    config.host    = ENV["ERRBIT_HOST"]
    config.port    = ENV["ERRBIT_PORT"]
    config.secure  = config.port == 443
  end
end

Faye::WebSocket.load_adapter('thin')

PrivatePub.config[:secret_token] = ENV['PRIVATE_PUB_SECRET_TOKEN']

run PrivatePub.faye_app
