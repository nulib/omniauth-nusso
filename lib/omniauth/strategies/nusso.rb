# frozen_string_literal: true

require 'faraday'
require 'json'
require 'omniauth'

module OmniAuth
  module Strategies
    class Nusso
      include OmniAuth::Strategy

      def initialize(app, options = {}, &block)
        super(app, { name: :nusso }.merge(options), &block)
        @config = options
      end

      def connection
        @connection ||= Faraday::Connection.new(@config[:base_url])
      end

      protected

        def request_phase
          session['omniauth.referer'] = request.referer
          response = get('get-ldap-redirect-url', goto: callback_url)
          redirect response.redirecturl
        end

      private

        def get(path, headers)
          headers = headers.merge(apikey: @config[:consumer_key])
          response = connection.get(path, nil, headers)
          case response.status
          when 200..299
            JSON.parse(response.body)
          when 407
            raise "Login Failed. Missing, invalid, or expired SSO Token"
          else
            raise "Unknown Response from #{path}"
          end
        end
    end
  end
end
