require 'rubygems' unless RUBY_VERSION >= '1.9'
require "bundler/setup"
require "sinatra/base"
require 'compass'
require "zurb-foundation"
require 'haml'

#configure { set :server, :puma }

class App < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  configure do
    Compass.configuration do |config|
      config.project_path = File.dirname __FILE__
      config.sass_dir = File.join "views", "scss"
      config.images_dir = File.join "views", "images"
      config.http_path = "/"
      config.http_images_path = "/images"
      config.http_stylesheets_path = "/stylesheets"
    end

    set :scss, Compass.sass_engine_options
    set :server, :puma
  end

  get "/stylesheets/*.css" do |path|
    content_type "text/css", charset: "utf-8"
    scss :"sass/#{path}"
  end

  get "/" do
    haml :index
  end

end
