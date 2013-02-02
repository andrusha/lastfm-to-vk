# encoding: utf-8
if RUBY_VERSION =~ /1.9/
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

require 'sinatra'
require 'omniauth'
require 'omniauth-vkontakte'
require 'slowweb'
require 'vkontakte_api'
require 'amatch'

enable :sessions
set    :session_secret, 'Once, there was a boy.'

use OmniAuth::Builder do
  provider :vkontakte, ENV['VK_API_KEY'], ENV['VK_API_SECRET'],
    scope: 'audio', display: 'page'
end

SlowWeb.limit 'api.vk.com', 3, 1

def is_valid_session?(session)
  session[:uid]        &&
  session[:token]      &&
  session[:expires_at] &&
  Time.now.getutc.to_i < session[:expires_at]
end

def has_file?(params)
  params[:file]            &&
  params[:file][:tempfile] &&
  params[:file][:filename]
end

def parse_tsv(file)
  # starting from the second line, split by tabs and keep
  # only first two entities (artist, track)
  file.readlines[1..-1].map! { |l| l.downcase.split("\t")[0..1].reverse! }
end

def normalize_song(song)
  song.map { |s| s.downcase.gsub(/[^\w]+/, ' ') }
end

def to_song_title(song)
  "#{song[0]} - #{song[1]}"
end

def remove_duplicates!(songs, present_songs)
  present_songs = Set.new present_songs.map! { |s| normalize_song [s.artist, s.title] }
  songs.delete_if { |s| present_songs.include? normalize_song(s) }
end

def closest_match(results, song)
  m = Amatch::Levenshtein.new to_song_title(song)
  results.sort_by! { |r| m.match to_song_title(normalize_song([r.artist, r.title])) }.first
end

def find_and_add(vk, song)
  results = vk.audio.search(q: to_song_title(song), count: 10)[1..-1]
  return puts "No results for #{song.inspect}" if results.nil?

  result = closest_match results, song
  return puts "Can't find #{result.inspect}"  if result.nil?
  vk.audio.add aid: result.aid, oid: result.owner_id
end

def job(token, songs)
  vk = VkontakteApi::Client.new token

  remove_duplicates! songs, vk.audio.get
  songs.reverse!  # because FILO
  songs.each { |s| find_and_add vk, s }
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
      job session[:token], parse_tsv(params[:file][:tempfile])[0..15]

      'fuck yea'
    end
  else
    'meow'
  end
end

get '/auth/vkontakte/callback' do
  session[:uid]        = request.env['omniauth.auth'].uid
  session[:token]      = request.env['omniauth.auth']['credentials'].token
  session[:expires_at] = request.env['omniauth.auth']['credentials'].expires_at

  redirect to '/'
end
