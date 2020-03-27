# frozen_string_literal: true

require 'faraday'
require 'json'
require 'omniauth'

module OmniAuth
  module Strategies
    class Nusso
      class AuthException < RuntimeError; end

      include OmniAuth::Strategy

      args [:base_url, :consumer_key]
      option :base_url, nil
      option :consumer_key, nil
      option :sso_cookie, 'nusso'
      option :include_attributes, true
      option :netid_email_domain, 'e.northwestern.edu'

      ATTRIBUTE_MAP = {
        name: 'displayName',
        email: 'mail',
        first_name: 'givenName',
        last_name: 'sn',
        phone: 'telephoneNumber',
        description: 'title'
      }.freeze

      def connection
        @connection ||= Faraday::Connection.new(options.base_url)
      end

      protected

        def request_phase
          response = get('get-ldap-redirect-url', goto: callback_url)
          redirect response['redirecturl']
        end

        def callback_phase
          token = request.cookies[options.sso_cookie]
          response = get('validateWebSSOToken', webssotoken: token)
          @user_info = { 'uid' => response['netid'] }
          if options.include_attributes
            @user_info.merge!(get_directory_attributes(token, response['netid']))
          end
          super
        rescue AuthException => err
          fail!(err.message)
        end

        uid { @user_info['uid'] }

        info do
          Hash[
            ATTRIBUTE_MAP.map do |key, user_info_key|
              [key, @user_info[user_info_key]]
            end
          ]
        end

        extra { { raw_info: @user_info } }

      private

        def get(path, headers)
          headers = headers.merge(apikey: options.consumer_key)
          response = connection.get(path, nil, headers)
          case response.status
          when 200..299
            JSON.parse(response.body)
          when 407
            raise AuthException, "Missing or Invalid Token"
          else
            raise AuthException, "Unknown Response"
          end
        end

        def netid_user(net_id)
          {
            'displayName' => net_id,
            'givenName' => net_id,
            'sn' => '(NetID)',
            'mail' => "#{net_id}@#{options.netid_email_domain}"
          }
        end

        def get_directory_attributes(token, net_id)
          response = get("validate-with-directory-search-response", webssotoken: token)
          Hash[
            response['results'].first.map do |k, v|
              case v
              when [] then nil
              when "" then nil
              when Array then [k, v.first]
              else [k, v]
              end
            end.compact
          ]
        rescue AuthException
          netid_user(net_id)
        end
    end
  end
end
