require 'rubygems' unless RUBY_VERSION >= '1.9'
require "bundler/setup"
require "sinatra/base"
require 'compass'
require "zurb-foundation"
require 'haml'
require 'dragonfly'
require 'mongoid'
require 'rack-flash'
require './helper/dragonfly_helper'

class App < Sinatra::Base
  helpers Sinatra::DragonflyHelper

  configure :production, :development do
    enable :logging
  end

  use Dragonfly::Middleware, :images

  app = Dragonfly[:images].configure_with(:imagemagick)

  app.datastore = Dragonfly::DataStorage::FileDataStore.new
  app.define_macro_on_include(Mongoid::Document, :image_accessor)

  app.configure do |d|
    d.datastore.root_path = File.join('upload')
    d.datastore.server_root = File.join('upload')
    d.url_format = '/images/:job/:basename.:format'
  end

  Mongoid.load!('config/mongoid.yml', ENV['RACK_ENV'] )

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
    enable :sessions
    use Rack::Flash, :sweep => true
  end

  class Picture
    include Mongoid::Document

    field :image_uid
    field :image_name
    field :base_path

    image_accessor :image
  end

  get "/stylesheets/*.css" do |path|
    content_type "text/css", charset: "utf-8"
    scss :"sass/#{path}"
  end

  get "/upload" do
    haml :upload
  end

  post "/upload" do
    if params[:file]
      filename = params[:file][:filename]
      file = params[:file][:tempfile]

      image_uid = app.store(file, :meta => {:time => Time.now, :name => filename})
      picture = Picture.create(image_uid: image_uid, image_name: filename)

      flash[:success] = "Upload successful of #{filename}"
      redirect "/gallery/#{picture.id}"
    else
      flash[:alert] = 'You have to choose a file first'
      redirect "/upload"
    end

  end

  get "/gallery" do
    @pictures = Picture.all
    haml :gallery
  end

  get '/gallery/:image_id' do |image_id|
    @image = Picture.find(image_id).image
    haml :show
  end

  get '/d/:image_id' do |image_id|
    Picture.find(image_id).image.thumb("200x200#").to_response(env)
  end

  get "/" do
    haml :index
  end

end
