require 'rubify/version'
require 'faraday'
require 'faraday_middleware'

module Rubify
  class Player
    PORT = 4371.freeze

    attr_accessor :oauth_token, :csrf_token, :domain

    def initialize
      @domain = 'https://' + SecureRandom.urlsafe_base64(10) + ".spotilocal.com:#{PORT}"
      fetch_oauth_token
      fetch_csrf_token
    end

    def status
      get('/remote/status.json').body
    end

    def play(spotify_uri)
      get('/remote/play.json', uri: spotify_uri, context: spotify_uri).body
    end

    def pause(should_pause = true)
      get('/remote/pause.json', pause: should_pause).body
    end

    def unpause
      pause(false)
    end

    private

    def get(url, params = {})
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
        request.headers['Referer'] = 'https://embed.spotify.com/remote-control-bridge/'
        request.headers['Origin'] = 'https://embed.spotify.com/'
      end
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
