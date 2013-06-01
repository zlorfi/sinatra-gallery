require 'rubygems' unless RUBY_VERSION >= '1.9'
require 'bundler/setup'
require 'sinatra/base'
require 'compass'
require 'zurb-foundation'
require 'haml'
require 'dragonfly'
require 'mongoid'
require 'rack-flash'
require 'nokogiri'
require 'open-uri'

class App < Sinatra::Base

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
    d.datastore.store_meta = false
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
      config.line_comments = false
      config.output_style = :compressed
    end

    set :scss, Compass.sass_engine_options
    set :server, :puma
    enable :sessions
    use Rack::Flash, :sweep => true

    #necessary for the DELETE route
    use Rack::MethodOverride

    #store the data in a seperate config file
    YAML::load(File.open('config/config.yml')).symbolize_keys.each do |key, value|
      set key, value
    end

  end

  class Picture
    include Mongoid::Document
    include Mongoid::Timestamps

    validates_numericality_of :sort_key, only_integer: true, greater_than: 0

    field :image_uid
    field :image_name
    field :image_title
    field :image_model
    field :base_path
    field :sort_key, type: Integer

    before_update :sort_things_right

    image_accessor :image

    def self.get_highest_key
      c = desc(:sort_key).limit(1).first
      c ? (c.sort_key + 1) : 1
    end

    def sort_things_right
      p self.sort_key 
    end

  end

  #before %r{\.(css)|(js)|(png)|(ico)} do
  #  response.headers['Cache-Control'] = 'public, max-age=604800'
  #end

  before do
    @p = Picture.all
    if @p.empty?
      flash[:notice] = "No documents found!"
    end
  end


  helpers do
    def asset_stylesheet(stylesheet)
      "/stylesheets/#{stylesheet}.css?" + File.mtime(File.join(Sinatra::Application.views, "sass", "#{stylesheet}.scss")).to_i.to_s
    end

    def asset_javascript(js)
      "/javascripts/#{js}.js?" + File.mtime(File.join(Sinatra::Application.public_folder, "javascripts", "#{js}.js")).to_i.to_s
    end

    def admin?
      request.cookies[settings.username] == settings.token
    end

    def protected!
      #halt [ 401, 'Not Authorized' ] unless admin?
      flash[:alert] = 'Not Authorized!' unless admin?
      halt haml(:error) unless admin?
    end

    def raw(text)
      Rack::Utils.escape_html(text)
    end

    def page_title
      settings.title
    end

    def piwik_site
      settings.piwik_site
    end

    def piwik_id
      settings.piwik_id
    end

  end

  get "/stylesheets/*.css" do |path|
    content_type "text/css", charset: "utf-8"
    response['Expires'] = (Time.now + 60*60*24*356*3).httpdate
    scss :"sass/#{path}"
  end

  get '/notification/:type/:message' do
    if request.xhr?
      flash.now[:"#{params[:type]}"] = params[:message].split('_').join(' ')
      haml :notification, :layout => !request.xhr?
    else
      redirect '/'
    end
  end

  post '/login' do
    if params['username']==settings.username && params['password']==settings.password
      response.set_cookie(settings.username, {:value => settings.token, :expires => Time.now + (60*60*24*2)}) 
      flash[:success] = "Login succeeded!"
      redirect '/'
    else
      flash[:alert] = "Login failed!"
      redirect '/'
    end
  end

  get '/logout' do
    response.set_cookie(settings.username, false)
    flash[:success] = "Logout successful!"
    redirect '/'
  end

  get "/upload" do
    protected!
    haml :upload, :layout => !request.xhr?
  end

  post "/upload" do
    protected!
    content_type 'application/json', :charset => 'utf-8' if request.xhr?
    if params[:file] && params[:file][:type].match(/image\/(gif|png|jpe?g)/)
      filename = params[:file][:filename]
      file = params[:file][:tempfile]
      
      prepared_image = app.fetch_file(file).process!(:resize, '1000x1000>')
      image_uid = app.store(prepared_image)
      picture = Picture.create(image_uid: image_uid, 
                               image_name: filename, 
                               image_title: params[:title], 
                               sort_key: Picture.get_highest_key
                              )

      flash[:success] = "Upload successful of #{filename}"
      redirect "/e/#{picture.id}" if !request.xhr?
      picture.to_json
    else
      flash[:alert] = 'You have to choose an image file first'
      redirect "/upload"
    end

  end

  put '/e/:image_id' do |image_id|
    protected!
    picture = Picture.find(image_id)
    picture.update_attributes(image_title: params[:title], sort_key: params[:sort_key])
    flash[:success] = "Update successful"
    redirect "/"
  end

  get '/e/:image_id' do |image_id|
    protected!
    @image = Picture.find(image_id).image
    @picture = Picture.find(image_id)
    haml :edit
  end

  get '/t/:image_id' do |image_id|
    Picture.find(image_id).image.thumb("400x400#").to_response(env)
  end

  delete '/d/:image_id' do |image_id|
    protected!
    p = Picture.find(image_id)
    if p.delete
      begin
        File.delete("upload/#{p.image_uid}")
        flash[:success] = "Image #{p.image_name} has been deleted"
        redirect '/'
      rescue => e
        flash[:alert] = "ERROR! #{e.message}"
        redirect '/'
      end
    else
      flash[:alert] = "ERROR!"
    end
  end

  get '/' do
    @awl = "http://www.amazon.de/registry/wishlist/#{settings.amazon_whishlist}"
    @pictures = Picture.all.asc(:sort_key)
    haml :index
  end

  not_found do
    flash[:notice] = "404 - Page not found"
    redirect '/'
  end

end
