# encoding: utf-8
if RUBY_VERSION =~ /1.9/
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

require 'sinatra'
require 'omniauth'
require 'omniauth-vkontakte'
require 'zurb-foundation'
require 'haml'
require 'sidekiq-status'

require './app/helpers'
require './app/jobs'

enable :logging
enable :sessions
set    :session_secret, 'Once, there was a boy.'
set    :haml, format: :html5
set    :scss, Compass.sass_engine_options

use OmniAuth::Builder do
  provider :vkontakte, ENV['VK_API_KEY'], ENV['VK_API_SECRET'],
    scope: 'audio', display: 'page'
end

Compass.configuration do |config|
  config.project_path = File.dirname __FILE__
  config.sass_dir = File.join "views", "scss"
  config.images_dir = File.join "views", "images"
  config.http_path = "/"
  config.http_images_path = "/images"
  config.http_stylesheets_path = "/stylesheets"
end


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
      job_id = ImportSongs.perform_async session[:token], parse_tsv(params[:file][:tempfile]).reverse

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

get "/stylesheets/*.css" do |path|
  content_type "text/css", charset: "utf-8"
  scss :"scss/#{path}"
end
