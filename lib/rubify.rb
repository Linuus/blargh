require 'rubify/version'
require 'faraday'
require 'faraday_middleware'

module Rubify
  class Player
    PORT = 4371.freeze

    attr_accessor :oauth_token, :csrf_token, :domain

    def initialize
      @domain = 'https://' + ('a'..'z').to_a.shuffle.first(10).join + '.spotilocal.com:4371'
      fetch_oauth_token
      fetch_csrf_token
    end

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
