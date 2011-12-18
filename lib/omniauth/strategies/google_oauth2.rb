require 'omniauth/strategies/oauth2'

module OmniAuth
  module Strategies
    class GoogleOauth2 < OmniAuth::Strategies::OAuth2

      # Possible scopes: userinfo.email,userinfo.profile,plus.me
      DEFAULT_SCOPE = "userinfo.email,userinfo.profile"

      option :name, 'google_oauth2'
      option :authorize_options, [:scope, :approval_prompt, :access_type]

      option :client_options, {
        :site          => 'https://accounts.google.com',
        :authorize_url => '/o/oauth2/auth',
        :token_url     => '/o/oauth2/token'
      }

      def authorize_params
        base_scope_url = "https://www.googleapis.com/auth/"
        super.tap do |params|
          scopes = (params[:scope] || DEFAULT_SCOPE).split(",")
          scopes.map! { |s| s =~ /^https?:\/\// ? s : "#{base_scope_url}#{s}" }
          params[:scope] = scopes.join(' ')
          # This makes sure we get a refresh_token.
          # http://googlecode.blogspot.com/2011/10/upcoming-changes-to-oauth-20-endpoint.html
          params[:access_type] = 'offline' if params[:access_type].nil?
          params[:approval_prompt] = 'force' if params[:approval_prompt].nil?
        end
      end

      uid{ raw_info['id'] || verified_email }

      info do
        prune!({
          :name       => raw_info['name'],
          :email      => verified_email,
          :first_name => raw_info['given_name'],
          :last_name  => raw_info['family_name'],
          :image      => raw_info['picture']
        })
      end

      extra do
        prune!({
          'raw_info' => raw_info
        })
      end

      def raw_info
        @raw_info ||= access_token.get('https://www.googleapis.com/oauth2/v1/userinfo').parsed
      end

      private

      def prune!(hash)
        hash.delete_if do |_, value|
          prune!(value) if value.is_a?(Hash)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end

      def verified_email
        raw_info['verified_email'] ? raw_info['email'] : nil
      end

    end
  end
end