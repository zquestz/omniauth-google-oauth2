# frozen_string_literal: true

require 'jwt'
require 'oauth2'
require 'omniauth/strategies/oauth2'
require 'openssl'
require 'stringio'
require 'uri'

module OmniAuth
  module Strategies
    # Main class for Google OAuth2 strategy.
    class GoogleOauth2 < OmniAuth::Strategies::OAuth2
      ALLOWED_ISSUERS = ['accounts.google.com', 'https://accounts.google.com'].freeze
      BASE_SCOPE_URL = 'https://www.googleapis.com/auth/'
      BASE_SCOPES = %w[profile email openid].freeze
      DEFAULT_SCOPE = 'email,profile'
      USER_INFO_URL = 'https://www.googleapis.com/oauth2/v3/userinfo'
      JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs'
      JWKS_CACHE_TTL = 3600
      JWKS_RETRY_INTERVAL = 60
      AUTHORIZE_OPTIONS = %i[access_type hd login_hint prompt request_visible_actions scope state redirect_uri include_granted_scopes enable_granular_consent openid_realm device_id device_name]

      JwksUnavailable = Class.new(StandardError)

      @jwks_mutex = Mutex.new

      class << self
        # Google's signing keys rotate, so the key set is shared across requests
        # and refetched on expiry or when a token names a kid we do not hold.
        # The fetch deliberately happens under the lock: concurrent callers wait
        # for one request rather than each issuing their own.
        def cached_jwks(force: false)
          @jwks_mutex.synchronize do
            now = ::Time.now.to_i

            # A forced refresh means some token named a kid we do not hold, which
            # the sender chooses freely. Honour it no more often than the retry
            # interval, or it becomes a way to drive unlimited fetches, each one
            # holding this lock while every other login waits.
            force &&= @jwks_forced_at.nil? || now >= @jwks_forced_at + JWKS_RETRY_INTERVAL

            if force || @jwks.nil? || now >= @jwks_expires_at.to_i
              # Back off even with nothing cached. Otherwise an unreachable
              # endpoint queues every waiting caller behind its own timeout,
              # since the lock serializes them and no expiry has been recorded.
              raise JwksUnavailable, 'within JWKS retry backoff' if @jwks.nil? && now < @jwks_retry_at.to_i

              @jwks_forced_at = now if force

              begin
                @jwks = yield
                @jwks_expires_at = ::Time.now.to_i + JWKS_CACHE_TTL
              rescue StandardError
                retry_at = ::Time.now.to_i + JWKS_RETRY_INTERVAL
                @jwks_retry_at = retry_at
                raise if @jwks.nil?

                # Google's keys outlive this cache by a wide margin, so serve the
                # stale set through a short outage rather than failing every
                # login, and back off instead of refetching on each request.
                @jwks_expires_at = retry_at
              end
            end
            @jwks
          end
        end

        def reset_jwks_cache!
          @jwks_mutex.synchronize do
            @jwks = nil
            @jwks_expires_at = nil
            @jwks_retry_at = nil
            @jwks_forced_at = nil
          end
        end
      end

      option :name, 'google_oauth2'
      option :skip_jwt, false
      option :jwt_leeway, 60
      option :authorize_options, AUTHORIZE_OPTIONS
      option :overridable_authorize_options, AUTHORIZE_OPTIONS
      option :authorized_client_ids, []

      option :client_options,
             site: 'https://oauth2.googleapis.com',
             authorize_url: 'https://accounts.google.com/o/oauth2/auth',
             token_url: '/token'

      def authorize_params
        super.tap do |params|
          (options[:authorize_options] & options[:overridable_authorize_options]).each do |k|
            params[k] = request.params[k.to_s] unless [nil, ''].include?(request.params[k.to_s])
          end

          params[:scope] = get_scope(params)
          params[:access_type] = 'offline' if params[:access_type].nil?
          params['openid.realm'] = params.delete(:openid_realm) unless params[:openid_realm].nil?

          session['omniauth.state'] = params[:state] if params[:state]
        end
      end

      uid { raw_info['sub'] }

      info do
        prune!(
          name: raw_info['name'],
          email: verified_email,
          unverified_email: raw_info['email'],
          email_verified: raw_info['email_verified'],
          first_name: raw_info['given_name'],
          last_name: raw_info['family_name'],
          image: image_url,
          urls: {
            google: raw_info['profile']
          }
        )
      end

      credentials do
        # Tokens and expiration will be used from OAuth2 strategy credentials block
        prune!({ 'scope' => token_info(access_token.token)['scope'] })
      end

      extra do
        hash = {}
        token = access_token['id_token']
        hash[:id_token] = token
        hash[:id_info] = id_token_claims(token) if !options[:skip_jwt] && !nil_or_empty?(token)
        hash[:raw_info] = raw_info unless skip_info?
        prune! hash
      end

      def raw_info
        @raw_info ||= access_token.get(USER_INFO_URL).parsed
      end

      def custom_build_access_token
        access_token = get_access_token(request)

        # Nothing in the request produced a usable credential. Raising here gives
        # the caller an ordinary auth failure; the alternative is omniauth-oauth2
        # calling #expired? on nil and the request dying with a NoMethodError.
        raise CallbackError.new(:invalid_credentials, 'No valid credentials were supplied in the callback request') if access_token.nil?

        verify_hd(access_token)
        access_token
      end

      alias build_access_token custom_build_access_token

      private

      def nil_or_empty?(obj)
        obj.is_a?(String) ? obj.empty? : obj.nil?
      end

      def trusted_client_ids
        [options.client_id, *Array(options.authorized_client_ids)].compact.uniq
      end

      def id_token_claims(token)
        return @id_token_claims if token == @id_token_claims_token && !@id_token_claims.nil?

        clear_id_token_claims

        # Safe to decode without a key only because every route into
        # access_token['id_token'] has already established trust: the token
        # endpoint delivers it over TLS from Google, and a caller-supplied one
        # is cached here only after verified_id_token has checked its signature.
        claims = ::JWT.decode(token, nil, false).first

        # We have to manually verify the claims because the third parameter to
        # JWT.decode is false since no verification key is provided.
        ::JWT::Claims.verify_payload!(claims,
                                      iss: ALLOWED_ISSUERS,
                                      aud: trusted_client_ids,
                                      exp: { leeway: options.jwt_leeway },
                                      nbf: { leeway: options.jwt_leeway })

        cache_id_token_claims(token, claims)
      end

      def cache_id_token_claims(token, claims)
        @id_token_claims_token = token
        @id_token_claims = claims
      end

      def clear_id_token_claims
        @id_token_claims_token = nil
        @id_token_claims = nil
      end

      def callback_url
        options[:redirect_uri] || (full_host + callback_path)
      end

      def get_access_token(request)
        verifier = request.params['code']
        redirect_uri = request.params['redirect_uri']
        access_token = request.params['access_token']
        if verifier && request.xhr?
          client_get_token(verifier, redirect_uri || 'postmessage')
        elsif verifier
          client_get_token(verifier, redirect_uri || callback_url)
        elsif access_token && verify_token(access_token)
          ::OAuth2::AccessToken.from_hash(client, direct_token_hash(access_token, request.params['id_token']))
        elsif request.content_type =~ /json/i
          begin
            raw_body = request.body.read
            # Rack 3 input streams are not required to be rewindable, so hand
            # downstream middlewares a fresh stream rather than rewinding this one.
            request.env['rack.input'] = StringIO.new(raw_body).tap(&:binmode)
            body = JSON.parse(raw_body)
            # Valid JSON that is not an object carries no credential, and
            # indexing it by string would raise rather than fall through.
            body = nil unless body.is_a?(Hash)
            verifier = body && body['code']
            access_token = body && body['access_token']
            redirect_uri ||= body && body['redirect_uri']
            if verifier
              client_get_token(verifier, redirect_uri || 'postmessage')
            elsif verify_token(access_token)
              ::OAuth2::AccessToken.from_hash(client, direct_token_hash(access_token, body['id_token']))
            end
          rescue JSON::ParserError => e
            warn "[omniauth google-oauth2] JSON parse error=#{e}"
          end
        end
      end

      # An id_token supplied by the caller is only as trustworthy as its
      # signature, so it is carried through only once Google has vouched for it.
      # Nothing else from the request is: refresh_token and expiry cannot be
      # verified at all, so they stay dropped.
      def direct_token_hash(access_token, raw_id_token)
        hash = { 'access_token' => access_token }
        id_token = verified_id_token(raw_id_token, access_token)
        hash['id_token'] = id_token if id_token
        hash
      end

      def verified_id_token(raw_id_token, access_token)
        clear_id_token_claims
        return nil if nil_or_empty?(raw_id_token)

        # Widening this list means revisiting at_hash_matches?, which hardcodes
        # SHA-256 because at_hash is defined over the digest named by the token's
        # own alg header.
        claims = ::JWT.decode(raw_id_token, nil, true,
                              algorithms: ['RS256'],
                              jwks: ->(opts) { google_jwks(force: opts[:invalidate]) },
                              iss: ALLOWED_ISSUERS, verify_iss: true,
                              aud: trusted_client_ids, verify_aud: true,
                              verify_expiration: true, exp_leeway: options.jwt_leeway,
                              verify_not_before: true, nbf_leeway: options.jwt_leeway).first
        return nil unless same_user?(claims, access_token)

        cache_id_token_claims(raw_id_token, claims)
        raw_id_token
      rescue StandardError => e
        # Fail closed. A token we cannot verify, for any reason including the
        # key set being unreachable, is discarded rather than trusted.
        warn "[omniauth google-oauth2] discarding unverified id_token: #{e.class}: #{e.message}"
        nil
      end

      # A signature proves Google issued the id_token, not that it describes the
      # same person as the access token it arrived beside. Without that, a
      # genuine id_token for one user could be presented with another user's
      # access token, leaving uid and extra.id_info describing different people.
      def same_user?(claims, access_token)
        return true if at_hash_matches?(claims, access_token)

        subjects_match?(claims, access_token)
      end

      # at_hash ties an id_token to one specific access token: the left half of
      # the SHA-256 of that token, base64url encoded. SHA-256 because the digest
      # follows the token's alg header, which the decode above pins to RS256.
      # Only a fast path, so absence and mismatch are both just "unproven here",
      # deferring to the subject check rather than deciding anything.
      def at_hash_matches?(claims, access_token)
        expected = claims['at_hash']
        return false if nil_or_empty?(expected)

        # Encoded with pack rather than Base64, which is a bundled gem as of
        # Ruby 3.4 and would become a dependency of every host application.
        # Compared with ==, not a constant-time helper: both sides derive from
        # the access token the caller just sent, so there is no secret to leak,
        # and OpenSSL.secure_compare does not exist before Ruby 2.7.
        digest = ::OpenSSL::Digest::SHA256.digest(access_token)[0, 16]
        [digest].pack('m0').tr('+/', '-_').delete('=') == expected
      end

      # The claim that actually matters: does the id_token describe the same
      # person the access token belongs to? Comparing subjects tests that
      # directly, where at_hash only tests it by proxy. It also stays correct
      # when a client refreshes its access token but forwards the id_token it
      # was originally issued, which is a legitimate at_hash mismatch.
      def subjects_match?(claims, access_token)
        subject = claims['sub']
        return false if nil_or_empty?(subject)
        return true if subject == userinfo_for(access_token)['sub']

        warn '[omniauth google-oauth2] discarding id_token: subject does not match the access token'
        false
      end

      # Memoized into the same ivar raw_info and verify_hd use, so the lookup is
      # shared rather than repeated. skip_info still governs whether any of this
      # reaches the auth hash; it trims output, it does not waive the check.
      def userinfo_for(access_token)
        @raw_info ||= ::OAuth2::AccessToken.from_hash(client, 'access_token' => access_token).get(USER_INFO_URL).parsed
      end

      def google_jwks(force: false)
        # Anchored to this class rather than self.class so that subclasses share
        # the one cache instead of each looking for state they do not own.
        GoogleOauth2.cached_jwks(force: force) do
          # Parsed from the body rather than the response wrapper, which warns
          # about the JWKS "keys" entry colliding with a built-in Hash method.
          ::JWT::JWK::Set.new(parse_jwks(client.request(:get, JWKS_URL).body))
        end
      end

      # Google returns a small, fixed shape. Anything else is treated as an
      # outage rather than coerced, since JWT::JWK::Set will happily build a key
      # set out of surprising input, including an HMAC key from a bare string.
      def parse_jwks(body)
        parsed = JSON.parse(body)
        raise JwksUnavailable, 'JWKS response was not an object' unless parsed.is_a?(Hash)
        raise JwksUnavailable, 'JWKS response had no keys array' unless parsed['keys'].is_a?(Array)

        parsed
      end

      def client_get_token(verifier, redirect_uri)
        client.auth_code.get_token(verifier, get_token_options(redirect_uri), get_token_params)
      end

      def get_token_params
        deep_symbolize(options.auth_token_params || {})
      end

      def get_scope(params)
        raw_scope = params[:scope] || DEFAULT_SCOPE
        scope_list = raw_scope.split.map { |item| item.split(',') }.flatten
        scope_list.map! { |s| s =~ %r{^https?://} || BASE_SCOPES.include?(s) ? s : "#{BASE_SCOPE_URL}#{s}" }
        scope_list.join(' ')
      end

      def verified_email
        raw_info['email_verified'] ? raw_info['email'] : nil
      end

      def get_token_options(redirect_uri = '')
        { redirect_uri: redirect_uri }.merge(token_params.to_hash(symbolize_keys: true))
      end

      def prune!(hash)
        hash.delete_if do |_, v|
          prune!(v) if v.is_a?(Hash)
          v.nil? || (v.respond_to?(:empty?) && v.empty?)
        end
      end

      def image_url
        return nil unless raw_info['picture']

        u = URI.parse(raw_info['picture'])

        md = u.path.to_s.match(/(.*)(=((w[0-9]*|h[0-9]*|s[0-9]*|c|p)-?)*)$/)

        # Check for sizing, remove if present.
        u.path = md[1] if md && !md[1].nil? && !md[2].nil?

        if image_size_opts_passed?
          u.path += image_params
          u.path = u.path.gsub('//', '/')
        end

        u.query = strip_unnecessary_query_parameters(u.query)

        u.to_s
      end

      def image_size_opts_passed?
        options[:image_size] || options[:image_aspect_ratio]
      end

      def image_params
        image_params = []
        case options[:image_size]
        when Integer
          image_params << "s#{options[:image_size]}"
        when Hash
          image_params << "w#{options[:image_size][:width]}" if options[:image_size][:width]
          image_params << "h#{options[:image_size][:height]}" if options[:image_size][:height]
        end
        image_params << 'c' if options[:image_aspect_ratio] == 'square'
        image_params << 'p' if options[:image_aspect_ratio] == 'smart'

        "=#{image_params.join('-')}"
      end

      def strip_unnecessary_query_parameters(query_parameters)
        # strip `sz` parameter (defaults to sz=50) which overrides `image_size` options
        return nil if query_parameters.nil?

        params = URI.decode_www_form(query_parameters)
        stripped_params = params.delete_if { |key, _value| key == 'sz' }

        # don't return an empty Hash since that would result
        # in URLs with a trailing ? character: http://image.url?
        return nil if stripped_params.empty?

        URI.encode_www_form(stripped_params)
      end

      def token_info(access_token)
        return nil unless access_token

        @token_info ||= Hash.new do |h, k|
          h[k] = client.request(:post, 'https://www.googleapis.com/oauth2/v3/tokeninfo', body: { access_token: access_token }).parsed
        end

        @token_info[access_token]
      end

      def verify_token(access_token)
        return false unless access_token

        token_info = token_info(access_token)
        trusted_client_ids.include?(token_info['aud'])
      end

      def verify_hd(access_token)
        return true unless options.hd

        @raw_info ||= access_token.get(USER_INFO_URL).parsed

        options.hd = options.hd.call if options.hd.is_a? Proc
        allowed_hosted_domains = Array(options.hd)

        raise CallbackError.new(:invalid_hd, 'Invalid Hosted Domain') unless allowed_hosted_domains.include?(@raw_info['hd']) || options.hd == '*'

        true
      end
    end
  end
end
