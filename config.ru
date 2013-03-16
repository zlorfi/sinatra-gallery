require 'rubygems' unless RUBY_VERSION >= '1.9'
require 'sinatra'
require 'rack/cache'
require "./app"

use Rack::Cache,
  :metastore   => 'file:./tmp/meta',
  :entitystore => 'file:./tmp/body',
  #:metastore   => 'memcached://localhost:11211/meta',
  #:entitystore => 'memcached://localhost:11211/body',
  :verbose     => true

#run Sinatra::Application
run App
