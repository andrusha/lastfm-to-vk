# encoding: utf-8
if RUBY_VERSION =~ /1.9/
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

require 'sinatra'
require 'omniauth'
require 'omniauth-vkontakte'
require 'resque'
require 'resque-remote'

require './app/helpers'
require './app/jobs'

enable :sessions
set    :session_secret, 'Once, there was a boy.'

use OmniAuth::Builder do
  provider :vkontakte, ENV['VK_API_KEY'], ENV['VK_API_SECRET'],
    scope: 'audio', display: 'page'
end


get '/' do
  if is_valid_session? session
    <<-HTML
      <form action="/" method="post" enctype="multipart/form-data">
        <input type="file" name="file">
        <input type="submit" value="Upload">
      </form>
    HTML
  else
    <<-HTML
      <a href='/auth/vkontakte'>Войти через vk.com</a>
    HTML
  end
end

post '/' do
  if has_file? params
    if File.extname(params[:file][:filename]) != '.tsv'
      "Incorrect file format, .tsv expected"
    else
      job_id = ImportSongs.create token: session[:token], songs: parse_tsv(params[:file][:tempfile])[0..15]

      "fuck yea #{job_id}"
    end
  else
    'meow'
  end
end

get '/auth/vkontakte/callback' do
  session[:token]      = request.env['omniauth.auth']['credentials'].token
  session[:expires_at] = request.env['omniauth.auth']['credentials'].expires_at

  redirect to '/'
end
