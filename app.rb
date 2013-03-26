require 'rubygems' unless RUBY_VERSION >= '1.9'
require 'bundler/setup'
require 'sinatra/base'
require 'compass'
require 'zurb-foundation'
require 'haml'
require 'dragonfly'
require 'mongoid'
require 'rack-flash'

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

    #necessary for the DELETE route when using 
    use Rack::MethodOverride

    set :username,'gallery'
    set :password,'gallery'
    # make this a huge random number
    # SecureRandom.urlsafe_base64(30, true)
    set :token,'SzXdCtiS4hmt6gXhS4NIahrfL7iH7aUb0DXd-B35' 
  end

  class Picture
    include Mongoid::Document

    field :image_uid
    field :image_name
    field :image_title
    field :image_date
    field :image_model
    field :base_path

    image_accessor :image
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
      halt [ 401, 'Not Authorized' ] unless admin?
      #flash[:alert] = "Login failed!"
      #halt haml :index unless admin?
    end

    def raw(text)
      Rack::Utils.escape_html(text)
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
    haml :upload, :layout => !request.xhr?
  end

  post "/upload" do
    protected!
    content_type 'application/json', :charset => 'utf-8' if request.xhr?
    if params[:file]
      filename = params[:file][:filename]
      file = params[:file][:tempfile]

      prepared_image = app.fetch_file(file).process!(:resize, '800x800>')
      image_uid = app.store(prepared_image, :meta => {:upload_time => Time.now, :name => filename})
      picture = Picture.create(image_uid: image_uid, 
                               image_name: filename, 
                               image_title: params[:title], 
                               image_date: Time.now
                              )

      flash[:success] = "Upload successful of #{filename}"
      redirect "/i/#{picture.id}" if !request.xhr?
      picture.to_json
    else
      flash[:alert] = 'You have to choose a file first'
      redirect "/upload"
    end

  end

  get '/i/:image_id' do |image_id|
    @image = Picture.find(image_id).image
    @picture = Picture.find(image_id)
    haml :show
  end

  get '/t/:image_id' do |image_id|
    Picture.find(image_id).image.thumb("400x400#").to_response(env)
  end

  delete '/delete/:image_id' do
    protected!
    p = Picture.find(params[:image_id])
    if p.delete
      File.delete("upload/#{p.image_uid}")
      flash[:success] = "Image #{p.image_name} has been deleted"
      redirect '/'
    else
      flash[:alert] = "ERROR!"
    end
  end

  get '/' do
    @pictures = Picture.all.asc(:image_date)
    haml :index
  end

  not_found do
    flash[:notice] = "404 - Page not found"
    redirect '/'
  end

end
