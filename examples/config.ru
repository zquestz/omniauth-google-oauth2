# Sample app for Google OAuth2 Strategy
# Run with "bundle exec rackup"

require 'rubygems'
require 'bundler'
require 'sinatra'
require 'omniauth'
require 'omniauth-google-oauth2'

class App < Sinatra::Base
  get '/' do
    <<-HTML
    <ul>
      <li><a href='/auth/google_oauth2'>Sign in with Google</a></li>
    </ul>
    HTML
  end

  get '/auth/:provider/callback' do
    content_type 'text/plain'
    request.env['omniauth.auth'].to_hash.inspect
  end
  
  get '/auth/failure' do
    content_type 'text/plain'
    request.env['omniauth.auth'].to_hash.inspect
  end
end

use Rack::Session::Cookie

use OmniAuth::Builder do
  provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET'], {
    :scope => 'https://www.googleapis.com/auth/plus.me https://www.googleapis.com/auth/plus.stream.read https://www.googleapis.com/auth/plus.stream.write https://www.googleapis.com/auth/plus.circles.read https://www.googleapis.com/auth/plus.circles.write'
  }
end

run App.new
