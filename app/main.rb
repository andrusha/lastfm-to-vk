# encoding: utf-8
if RUBY_VERSION =~ /1.9/
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

require 'sinatra/base'
require 'sinatra/assetpack'
require 'compass'
require 'sinatra/support'
require 'omniauth'
require 'omniauth-vkontakte'
require 'zurb-foundation'
require 'haml'
require 'sidekiq-status'

require './app/helpers'
require './app/jobs'

class App < Sinatra::Base
  enable :logging
  enable :sessions
  set    :session_secret, 'Once, there was a boy.'
  set    :haml, format: :html5
  set    :root, File.dirname(__FILE__)

  register Sinatra::CompassSupport
  Compass.configuration do |config|
    config.project_path = root
    config.images_dir = 'views/images'
    config.http_images_path = "/img"
  end

  register Sinatra::AssetPack
  assets {
    prebuild true

    css   :app,   ['/css/*.css']
    serve '/css', from: 'views/scss'
    serve '/img', from: 'views/images'

    css_compression :yui
    js_compression  :yui, munge: true
  }

  use OmniAuth::Builder do
    provider :vkontakte, ENV['VK_API_KEY'], ENV['VK_API_SECRET'],
      scope: 'audio', display: 'page'
  end

  use Rack::Deflater


  get '/' do
    if is_valid_session? session
      haml :upload
    else
      haml :login
    end
  end

  post '/' do
    if has_file? params
      if File.extname(params[:file][:filename]) != '.tsv'
        haml :upload
      else
        songs  = parse_tsv(params[:file][:tempfile]).reverse
        job_id = ImportSongs.perform_async session[:token], songs, params[:gid]

        redirect to "/status/#{job_id}"
      end
    else
      redirect to '/'
    end
  end

  get '/status/:job_id' do |job_id|
    status = Sidekiq::Status::get job_id

    haml :status, locals: {status: status}
  end

  get '/auth/vkontakte/callback' do
    session[:token]      = request.env['omniauth.auth']['credentials'].token
    session[:expires_at] = request.env['omniauth.auth']['credentials'].expires_at

    redirect to '/'
  end

end
