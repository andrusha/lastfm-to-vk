require 'resque'
require 'resque-status'
require 'slowweb'
require 'vkontakte_api'
require 'amatch'

Resque.redis = ENV['REDISCLOUD_URL'] || 'redis://localhost:6379'
SlowWeb.limit 'api.vk.com', 3, 1

class ImportSongs
  include Resque::Plugins::Status

  def perform
    vk = VkontakteApi::Client.new options['token']

    songs = options['songs']
    remove_duplicates! songs, vk.audio.get
    songs.reverse!  # because FILO
    songs.each_with_index do |s, i|
      at i, songs.length
      find_and_add vk, s
    end
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
end
