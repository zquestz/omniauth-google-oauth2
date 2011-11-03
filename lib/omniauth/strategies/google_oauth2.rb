require 'omniauth/strategies/oauth2'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

module OmniAuth
  module Strategies
    class GoogleOauth2 < OmniAuth::Strategies::OAuth2
      option :name, 'google_oauth2'
      option :client_options, {
        :site => 'https://accounts.google.com',
        :authorize_url => '/o/oauth2/auth',
        :token_url => '/o/oauth2/token'
      }

      def request_phase
        redirect client.auth_code.authorize_url({
          :redirect_uri => callback_url, 
          :response_type => "code"}.merge(authorize_options)
        )
      end

      def authorize_options
        opts = {
          :client_id => options[:client_id],
          :redirect_url => callback_url,
          :response_type => "code",
          :scope => options[:scope]
        }
        google_email_scope = "www.googleapis.com/auth/userinfo.email"
        opts[:scope] ||= "https://#{google_email_scope}"
        opts[:scope] << " https://#{google_email_scope}" unless options[:scope] =~ %r[http[s]?:\/\/#{google_email_scope}]
        opts
      end

      def auth_hash
        OmniAuth::Utils.deep_merge(super, {
          'uid' => info['uid'],
          'info' => info,
          'credentials' => {'expires_at' => @access_token.expires_at},
          'extra' => {'user_hash' => user_data}
        })
      end

      info do
        {
          'email' => "TESTING EMAIL",
          'uid' => "TESTING UID",
          'name' => "TESTING NAME"
        }
      end

      def user_data
        @data ||= 
          @access_token.get("https://www.googleapis.com/userinfo/email?alt=json").parsed
      end
    end
  end
end