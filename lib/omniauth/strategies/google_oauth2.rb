require 'omniauth/strategies/oauth2'

module OmniAuth
  module Strategies
    class GoogleOAuth2 < OmniAuth::Strategies::OAuth2
      option :name, 'google_oauth2'

      option :client_options, {
        :site => 'https://accounts.google.com',
        :authorize_url => '/o/oauth2/auth',
        :token_url => '/o/oauth2/token'
      }

      def request_phase
        setup_authorize_params
        super
      end

      def setup_authorize_params
        opts = {
          :client_id => options[:client_id],
          :redirect_uri => callback_url,
          :response_type => "code",
          :scope => options[:scope]
        }
        google_email_scope = "www.googleapis.com/auth/userinfo.email"
        opts[:scope] ||= "https://#{google_email_scope}"
        opts[:scope] << " https://#{google_email_scope}" unless opts[:scope] =~ %r[http[s]?:\/\/#{google_email_scope}]
        options[:authorize_params] = opts.merge(options[:authorize_params])
      end

      def auth_hash
        OmniAuth::Utils.deep_merge(super, {
          'uid' => info['uid'],
          'info' => info,
          'credentials' => {'expires_at' => access_token.expires_at},
          'extra' => {'user_hash' => user_data}
        })
      end

      info do
        if user_data['data']['isVerified']
          email = user_data['data']['email'] rescue nil
        else
          email = nil
        end

        {
          'email' => email,
          'uid' => email,
          'name' => email
        }
      end

      def user_data
        @data ||= access_token.get("https://www.googleapis.com/userinfo/email?alt=json").parsed
      end
    end
  end
end