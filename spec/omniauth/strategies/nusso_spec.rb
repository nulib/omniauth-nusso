# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniAuth::Strategies::Nusso do
  let(:auth_server) { 'https://prd-nusso.it.northwestern.edu/nusso/XUI/' }
  let(:netid) { 'abc123' }
  let(:user_info) do
    <<__EOC__
    {
      "results": [
        {
          "displayName": ["Archie B. Charles"],
          "eduPersonNickname": [],
          "givenName": ["Archie B."],
          "mail": "archie.charles@example.edu",
          "nuOtherTitle": "",
          "nuStudentEmail": "",
          "nuTelephoneNumber2": "",
          "nuTelephoneNumber3": "",
          "sn": ["Charles"],
          "telephoneNumber": "+1 847 555 5555",
          "title": ["Test Dummy"]
        }
      ]
    }
__EOC__
  end
  let(:empty_user_info) do
    <<__EOC__
    {
      "results": [{
        "displayName": [],
        "givenName": [],
        "sn": [],
        "eduPersonNickname": [],
        "mail": "",
        "nuStudentEmail": "",
        "title": [],
        "telephoneNumber": "",
        "nuTelephoneNumber2": "",
        "nuTelephoneNumber3": "",
        "nuOtherTitle": ""
      }]
    }
__EOC__
  end

  def app
    Rack::Builder.new do
      use OmniAuth::Test::PhonySession
      use OmniAuth::Builder do
        provider OmniAuth::Strategies::Nusso,
                 'https://test.example.edu/agentless-websso/',
                 'test-consumer-key'
      end
      run ->(env) { [404, { "Content-Type" => "text/plain" }, [env.key?("omniauth.auth").to_s]] }
    end.to_app
  end

  def session
    last_request.env['rack.session']
  end

  describe '/auth/nusso' do
    before do
      stub_request(:get, 'https://test.example.edu/agentless-websso/get-ldap-redirect-url')
        .with(
          headers: {
            'Apikey' => 'test-consumer-key',
            'Goto' => 'http://example.org/auth/nusso/callback'
          }
        )
        .to_return(body: %({"redirecturl": "#{auth_server}?#login&realm=northwestern&authIndexType=service&service=ldap-registry&goto=http://example.org/auth/nusso/callback"}))
    end

    context 'successful' do
      before do
        get '/auth/nusso'
      end

      it 'redirects to authorize_url' do
        expect(last_response).to be_redirect
        expect(last_response.headers['Location']).to eq("#{auth_server}?#login&realm=northwestern&authIndexType=service&service=ldap-registry&goto=http://example.org/auth/nusso/callback")
      end
    end
  end

  describe '/auth/nusso/callback' do
    context 'successful' do
      before do
        stub_request(:get, 'https://test.example.edu/agentless-websso/validateWebSSOToken')
          .with(
            headers: {
              'Apikey' => 'test-consumer-key',
              'Webssotoken' => 'success-token'
            }
          )
          .to_return(body: %({"netid": "#{netid}"}))

        stub_request(:get, 'https://test.example.edu/agentless-websso/validate-with-directory-search-response')
          .with(
            headers: {
              'Apikey' => 'test-consumer-key',
              'Webssotoken' => 'success-token'
            }
          )
          .to_return(body: user_info)

        set_cookie('nusso=success-token')
        get '/auth/nusso/callback'
      end

      it 'contains user info' do
        expect(last_request.env['omniauth.auth']['uid']).to eq('abc123')
        expect(last_request.env['omniauth.auth']['info']['name']).to eq('Archie B. Charles')
        expect(last_request.env['omniauth.auth']['info']['email']).to eq('archie.charles@example.edu')
      end
    end

    context 'bad token' do
      before do
        stub_request(:get, 'https://test.example.edu/agentless-websso/validateWebSSOToken')
          .with(
            headers: {
              'Apikey' => 'test-consumer-key',
              'Webssotoken' => 'bad-token'
            }
          )
          .to_return(status: 407, body: %({"error": "Missing or Invalid Token"}))

        set_cookie('nusso=bad-token')
        get '/auth/nusso/callback'
      end

      it 'redirects with failure message' do
        expect(last_response).to be_redirect
        expect(last_response.headers['Location']).to match(%r{^/auth/failure?.*message=Missing or Invalid Token})
      end
    end

    context 'unknown response' do
      before do
        stub_request(:get, 'https://test.example.edu/agentless-websso/validateWebSSOToken')
          .with(
            headers: {
              'Apikey' => 'test-consumer-key',
              'Webssotoken' => 'bad-token'
            }
          )
          .to_return(status: 418, body: "I'm a teapot")

        set_cookie('nusso=bad-token')
        get '/auth/nusso/callback'
      end

      it 'redirects with failure message' do
        expect(last_response).to be_redirect
        expect(last_response.headers['Location']).to match(%r{^/auth/failure?.*message=Unknown Response})
      end
    end
  end

  context 'no directory entry' do
    before do
      stub_request(:get, 'https://test.example.edu/agentless-websso/validateWebSSOToken')
      .with(
        headers: {
          'Apikey' => 'test-consumer-key',
          'Webssotoken' => 'success-token'
        }
      )
      .to_return(body: %({"netid": "#{netid}"}))

      stub_request(:get, 'https://test.example.edu/agentless-websso/validate-with-directory-search-response')
      .with(
        headers: {
          'Apikey' => 'test-consumer-key',
          'Webssotoken' => 'success-token'
        }
      )
      .to_return(status: 500, body: '{"fault":{"faultstring":"Execution of ServiceCallout Call-Directory-Search failed. Reason: ResponseCode 404 is treated as error","detail":{"errorcode":"steps.servicecallout.ExecutionFailed"}}}')

      set_cookie('nusso=success-token')
      get '/auth/nusso/callback'
    end

    it 'contains computed user info' do
      expect(last_request.env['omniauth.auth']['uid']).to eq('abc123')
      expect(last_request.env['omniauth.auth']['info']['name']).to eq('abc123')
      expect(last_request.env['omniauth.auth']['info']['email']).to eq('abc123@e.northwestern.edu')
    end
  end

  context 'blank directory entry' do
    before do
      stub_request(:get, 'https://test.example.edu/agentless-websso/validateWebSSOToken')
      .with(
        headers: {
          'Apikey' => 'test-consumer-key',
          'Webssotoken' => 'success-token'
        }
      )
      .to_return(body: %({"netid": "#{netid}"}))

      stub_request(:get, 'https://test.example.edu/agentless-websso/validate-with-directory-search-response')
      .with(
        headers: {
          'Apikey' => 'test-consumer-key',
          'Webssotoken' => 'success-token'
        }
      )
      .to_return(status: 200, body: '')

      set_cookie('nusso=success-token')
      get '/auth/nusso/callback'
    end

    it 'contains computed user info' do
      expect(last_request.env['omniauth.auth']['uid']).to eq('abc123')
      expect(last_request.env['omniauth.auth']['info']['name']).to eq('abc123')
      expect(last_request.env['omniauth.auth']['info']['email']).to eq('abc123@e.northwestern.edu')
    end
  end

  context 'empty directory entry' do
    before do
      stub_request(:get, 'https://test.example.edu/agentless-websso/validateWebSSOToken')
        .with(
          headers: {
            'Apikey' => 'test-consumer-key',
            'Webssotoken' => 'success-token'
          }
        )
        .to_return(body: %({"netid": "#{netid}"}))

      stub_request(:get, 'https://test.example.edu/agentless-websso/validate-with-directory-search-response')
        .with(
          headers: {
            'Apikey' => 'test-consumer-key',
            'Webssotoken' => 'success-token'
          }
        )
        .to_return(body: empty_user_info)

      set_cookie('nusso=success-token')
      get '/auth/nusso/callback'
    end

    it 'contains computed user info' do
      expect(last_request.env['omniauth.auth']['uid']).to eq('abc123')
      expect(last_request.env['omniauth.auth']['info']['name']).to eq('abc123')
      expect(last_request.env['omniauth.auth']['info']['email']).to eq('abc123@e.northwestern.edu')
    end
  end
end
