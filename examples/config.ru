# frozen_string_literal: true

# Sample app for Google OAuth2 Strategy
# Make sure to setup the ENV variables GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
# and RACK_COOKIE_SECRET
# Run with "bundle exec rackup"

require 'rubygems'
require 'bundler'
require 'sinatra'
require 'omniauth'
require 'omniauth-google-oauth2'

# OmniAuth re-raises authentication failures in development by default, and
# `rackup` runs in development, so the sample would show a stack trace where a
# deployed app redirects to /auth/failure. Clearing this lets the example
# demonstrate the failure a real application would see.
OmniAuth.config.failure_raise_out_environments = []

# Main example app for omniauth-google-oauth2
class App < Sinatra::Base
  configure do
    set :sessions, true
    set :inline_templates, true
  end

  use Rack::Session::Cookie, secret: ENV['RACK_COOKIE_SECRET']

  use OmniAuth::Builder do
    # For additional provider examples please look at 'omni_auth.rb'
    # The key provider_ignores_state is only for AJAX flows. It is not recommended for normal logins.
    provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], access_type: 'offline', prompt: 'consent', provider_ignores_state: true, scope: 'email,profile'
  end

  get '/' do
    <<-HTML
    <!DOCTYPE html>
    <html>
      <head>
        <title>Google OAuth2 Example</title>
      </head>

      <body>
        <ul>
          <li>
            <form method="post" action="/auth/google_oauth2">
              <input type="hidden" name="authenticity_token" value="#{request.env['rack.session']['csrf']}">
              <button type="submit">Login with Google</button>
            </form>
          </li>

          <li>
            <a href="#" class="googleplus-login">Sign in with Google via AJAX</a>
          </li>
        </ul>

        <script>
          const a = document.querySelector('.googleplus-login');

          const handleGoogleOauthSignIn = () => {
            const oauth2Endpoint = 'https://accounts.google.com/o/oauth2/v2/auth';

            const params = new URLSearchParams({
              client_id: '#{ENV['GOOGLE_CLIENT_ID']}',
              prompt: 'select_account',
              redirect_uri: 'http://localhost:3000/callback',
              response_type: 'code',
              scope: 'email openid profile',
            });

            const url = `${oauth2Endpoint}?${params.toString()}`;
            window.location.href = url;
          }

          a.addEventListener('click', event => {
            event.preventDefault();
            handleGoogleOauthSignIn();
          });
        </script>
      </body>
    </html>
    HTML
  end

  get '/callback' do
    <<-HTML
    <!DOCTYPE html>
    <html>
      <head>
        <title>Google OAuth2 Example</title>
      </head>

      <body>
        <h1>Google OAuth2 Example</h1>
        <p>Posting the one-time code to the callback. The auth hash appears below.</p>
        <p id="status">Working...</p>
        <code id="result" style="white-space: pre-wrap; overflow-wrap: anywhere; display: block;"></code>

        <script>
          const handleGoogleOauthCallback = async () => {
            const params = new URL(document.location.toString()).searchParams;
            const code = params.get('code');
            const status = document.querySelector('#status');
            const output = document.querySelector('#result');

            if (!code) {
              status.textContent = 'No code parameter in the URL.';
              return;
            }

            try {
              const response = await fetch('http://localhost:3000/auth/google_oauth2/callback', {
                body: JSON.stringify({ code, redirect_uri: 'http://localhost:3000/callback' }),
                headers: {
                  'Content-type': 'application/json',
                },
                method: 'POST',
              });

              status.textContent = `${response.status} ${response.statusText}`;
              output.textContent = await response.text();
            } catch (error) {
              status.textContent = `Request failed: ${error}`;
            }
          }

          handleGoogleOauthCallback();
        </script>
      </body>
    </html>
    HTML
  end

  post '/auth/:provider/callback' do
    content_type 'text/plain'
    begin
      request.env['omniauth.auth'].to_hash.inspect
    rescue StandardError
      'No Data'
    end
  end

  get '/auth/:provider/callback' do
    content_type 'text/plain'
    begin
      request.env['omniauth.auth'].to_hash.inspect
    rescue StandardError
      'No Data'
    end
  end

  # omniauth.auth is never set on a failure, so report what OmniAuth does pass:
  # the failure reason and the strategy that produced it.
  get '/auth/failure' do
    content_type 'text/plain'
    <<~TEXT
      Authentication failed
      message:  #{params['message'] || 'unknown'}
      strategy: #{params['strategy'] || 'unknown'}
    TEXT
  end
end

run App.new
