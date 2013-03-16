require 'rubygems' unless RUBY_VERSION >= '1.9'
require "bundler/setup"
require "sinatra/base"
require 'compass'
require "zurb-foundation"
require 'haml'
require 'dragonfly'
require 'mongoid'

#configure { set :server, :puma }

class App < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  app = Dragonfly[:images].configure_with(:imagemagick)

  app.datastore = Dragonfly::DataStorage::FileDataStore.new
  app.define_macro_on_include(Mongoid::Document, :image_accessor)

  app.datastore.configure do |d|
    d.root_path = File.join('upload')
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
  end

  helpers do
    def flash(message = '')
      session[:flash] = message
    end
  end

  before do
    @flash = session.delete(:flash)
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

  get "/" do
    haml :index
  end

  get "/upload" do
    haml :upload
  end

  post "/upload" do
    if params[:file]
      filename = params[:file][:filename]
      file = params[:file][:tempfile]

      image_uid = app.store(file)
      picture = Picture.create(image_uid: image_uid, image_name: filename)

      flash "Upload successful of #{filename}"
    else
      flash 'You have to choose a file'
    end

    redirect '/upload'
  end

end
