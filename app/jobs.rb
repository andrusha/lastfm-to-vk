require 'sidekiq'
require 'sidekiq-status'
require 'sidekiq/middleware/server/retry_jobs'
require 'slowweb'
require 'vkontakte_api'
require 'amatch'


# vk.com limits to 3/sec api requests
# 10/min, 50/hr audio.add requests
SlowWeb.limit 'api.vk.com', 3, 1
Sidekiq::Middleware::Server::RetryJobs.send(:remove_const, 'DELAY')
Sidekiq::Middleware::Server::RetryJobs.const_set('DELAY', proc { |count| [60, 60*60][count] || count*60*60 })
Sidekiq::Status.send(:remove_const, 'DEFAULT_EXPIRY')
Sidekiq::Status.const_set('DEFAULT_EXPIRY', 2*24*60*60)
Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Status::ClientMiddleware
  end
end
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Status::ServerMiddleware
  end
end


module ImportHelpers
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
end


class ImportSongs
  include ImportHelpers
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options :retry => 5

  def perform(token, songs, gid = nil)
    vk = VkontakteApi::Client.new token

    params = gid.empty? ? {} : {gid: gid}
    remove_duplicates! songs, vk.audio.get(params)
    songs.each do |song|
      find_and_add vk, song, gid
    end
  end

  def find_and_add(vk, song, gid = nil)
    results = vk.audio.search(q: to_song_title(song), count: 10)[1..-1]
    return puts "No results for #{song.inspect}"  if results.nil?

    result = closest_match results, song
    return puts "Can't find #{result.inspect}"    if result.nil?

    params       = {aid: result.aid, oid: result.owner_id}
    params[:gid] = gid  unless gid.empty?
    vk.audio.add params
  end

end
