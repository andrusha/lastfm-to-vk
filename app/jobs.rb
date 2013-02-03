require 'sidekiq'
require 'sidekiq/middleware/server/retry_jobs'
require 'slowweb'
require 'vkontakte_api'
require 'amatch'

# limit to 3 requests per second
SlowWeb.limit 'api.vk.com', 3, 1


Sidekiq::Middleware::Server::RetryJobs.send(:remove_const, 'DELAY')
Sidekiq::Middleware::Server::RetryJobs.const_set('DELAY', proc { |count| [60, 60*60][count] || count*60*60 })

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

  sidekiq_options :retry => 3

  def perform(token, songs)
    vk = VkontakteApi::Client.new token

    remove_duplicates! songs, vk.audio.get

    songs.each do |song|
      find_and_add vk, song
    end
  end

  def find_and_add(vk, song)
    results = vk.audio.search(q: to_song_title(song), count: 10)[1..-1]
    return puts "No results for #{song.inspect}"  if results.nil?

    result = closest_match results, song
    return puts "Can't find #{result.inspect}"    if result.nil?
    vk.audio.add aid: result.aid, oid: result.owner_id
  end

end
