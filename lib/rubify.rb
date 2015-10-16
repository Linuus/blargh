require 'rubify/version'
require 'faraday'
require 'faraday_middleware'
require 'rspotify'

module Rubify
  class Player
    PORT = 4370

    attr_accessor :oauth_token, :csrf_token, :domain

    def initialize
      @domain = 'https://' + SecureRandom.urlsafe_base64(10) + ".spotilocal.com:#{PORT}"
      fetch_tokens if running?
    end

    def running?
      version.fetch('running', true)
    end

    def version
      get('/service/version.json', params: { service: 'remote' }).body
    end

    def open
      get('/remote/open.json').body
    end

    def status
      get('/remote/status.json').body
    end

    def playing?
      get('/remote/status.json').body['playing']
    end

    def play_percent
      _status = status
      (_status['playing_position']/_status['track']['length'] * 100).round.to_s + '%'
    end

    def current_track
      _status = status
      "#{_status['track']['artist_resource']['name']} - #{_status['track']['track_resource']['name']}"
    end

    def play(spotify_uri)
      get('/remote/play.json', params: { uri: spotify_uri, context: spotify_uri }).body
    end

    def pause(should_pause = true)
      get('/remote/pause.json', params: { pause: should_pause }).body
    end

    def unpause
      pause(false)
    end

    def play_search(artist: nil, track: '')
      search = ::RSpotify::Track.search(track)
      candidate = if artist.nil?
                    search.first
                  else
                    search.find { |tracks| tracks.artists.any? { |a| a.name.downcase == artist.downcase } }
                  end
      if candidate
        play(candidate.uri)
      else
        puts 'No match'
      end
    end

    private

    def get(url, params: {}, headers: {})
      default_headers = {
        'Referer' => 'https://embed.spotify.com/remote-control-bridge/',
        'Origin'  => 'https://embed.spotify.com/'
      }
      @connection ||= Faraday.new(
        url: domain,
        ssl: { verify: false }
      ) do |config|
        config.response :json
        config.adapter Faraday.default_adapter
      end

      params = { 'oauth' => oauth_token,
                 'csrf'  => csrf_token }.merge(params)

      @connection.get do |request|
        request.url url
        request.params = params
        request.headers = default_headers.merge(headers)
      end

    rescue Faraday::ConnectionFailed
      puts 'Connection failed. Player is probably not running.'
    end

    def fetch_tokens
      fetch_oauth_token
      fetch_csrf_token
    end

    def fetch_oauth_token
      oauth_connection = Faraday.new(
        url: 'https://embed.spotify.com/remote-control-bridge/'
      ) do |config|
        config.adapter Faraday.default_adapter
      end

      response = oauth_connection.get do |request|
        request.headers['Referer'] = 'https://embed.spotify.com/remote-control-bridge/'
        request.headers['Origin'] = 'https://embed.spotify.com/'
      end
      self.oauth_token = response.body[/tokenData = '(.*)'/, 1]
    end

    def fetch_csrf_token
      response = get('/simplecsrf/token.json')
      self.csrf_token = response.body['token']
    end
  end
end
