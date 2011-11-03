require 'rubygems'
require 'bundler'

Bundler.setup :default, :development, :example
require 'sinatra'
require 'omniauth'
require 'omniauth-google-oauth2'

use Rack::Session::Cookie

use OmniAuth::Builder do
  provider :google_oauth2,  ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET']
end

get '/' do
  <<-HTML
  <ul>
    <li><a href='/auth/google_oauth2'>Sign in with Google</a></li>
  </ul>
  HTML
end

get '/auth/:provider/callback' do
  content_type 'text/plain'
  request.env['omniauth.auth'].info.to_hash.inspect
end
