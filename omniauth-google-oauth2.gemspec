# -*- encoding: utf-8 -*-
require File.expand_path(File.join('..', 'lib', 'omniauth', 'google_oauth2', 'version'), __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "omniauth-google-oauth2"
  gem.version       = OmniAuth::GoogleOauth2::VERSION
  gem.license       = 'MIT'
  gem.summary       = %q{A Google OAuth2 strategy for OmniAuth 1.x}
  gem.description   = %q{A Google OAuth2 strategy for OmniAuth 1.x}
  gem.authors       = ["Josh Ellithorpe", "Yury Korolev"]
  gem.email         = ["quest@mac.com"]
  gem.homepage      = "https://github.com/zquestz/omniauth-google-oauth2"

  gem.files         = `git ls-files`.split("\n")
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'omniauth', '>= 1.1.1'
  gem.add_runtime_dependency 'omniauth-oauth2', '>= 1.1.1'
  gem.add_runtime_dependency 'jwt', '~> 1.0'
  gem.add_runtime_dependency 'multi_json', '~> 1.3'
  gem.add_runtime_dependency 'addressable', '~> 2.3'

  gem.add_development_dependency 'rspec', '>= 2.14.0'
  gem.add_development_dependency 'rake'
end
