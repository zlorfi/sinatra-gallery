require 'rubygems' unless RUBY_VERSION >= '1.9'
require 'sinatra'
require 'rack/cache'
require "./app"

if ENV["RACK_ENV"] == 'production'
  use Rack::Cache,
  :metastore   => 'memcached://localhost:11211/meta',
  :entitystore => 'memcached://localhost:11211/body',
  :verbose     => true
else
  use Rack::Cache,
  :metastore   => 'file:./tmp/meta',
  :entitystore => 'file:./tmp/body',
  :verbose     => true
end

run App
