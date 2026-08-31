# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'omniauth-google-oauth2'
require 'openssl'
require 'stringio'

describe OmniAuth::Strategies::GoogleOauth2 do
  let(:request) { double('Request', params: {}, cookies: {}, env: {}) }
  let(:app) do
    lambda do
      [200, {}, ['Hello.']]
    end
  end

  subject do
    OmniAuth::Strategies::GoogleOauth2.new(app, 'appid', 'secret', @options || {}).tap do |strategy|
      allow(strategy).to receive(:request) do
        request
      end
    end
  end

  before do
    OmniAuth.config.test_mode = true
    # The key set is cached on the class, so it must not leak between examples.
    OmniAuth::Strategies::GoogleOauth2.reset_jwks_cache!
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe '#client_options' do
    it 'has correct site' do
      expect(subject.client.site).to eq('https://oauth2.googleapis.com')
    end

    it 'has correct authorize_url' do
      expect(subject.client.options[:authorize_url]).to eq('https://accounts.google.com/o/oauth2/auth')
    end

    it 'has correct token_url' do
      expect(subject.client.options[:token_url]).to eq('/token')
    end

    describe 'overrides' do
      context 'as strings' do
        it 'should allow overriding the site' do
          @options = { client_options: { 'site' => 'https://example.com' } }
          expect(subject.client.site).to eq('https://example.com')
        end

        it 'should allow overriding the authorize_url' do
          @options = { client_options: { 'authorize_url' => 'https://example.com' } }
          expect(subject.client.options[:authorize_url]).to eq('https://example.com')
        end

        it 'should allow overriding the token_url' do
          @options = { client_options: { 'token_url' => 'https://example.com' } }
          expect(subject.client.options[:token_url]).to eq('https://example.com')
        end
      end

      context 'as symbols' do
        it 'should allow overriding the site' do
          @options = { client_options: { site: 'https://example.com' } }
          expect(subject.client.site).to eq('https://example.com')
        end

        it 'should allow overriding the authorize_url' do
          @options = { client_options: { authorize_url: 'https://example.com' } }
          expect(subject.client.options[:authorize_url]).to eq('https://example.com')
        end

        it 'should allow overriding the token_url' do
          @options = { client_options: { token_url: 'https://example.com' } }
          expect(subject.client.options[:token_url]).to eq('https://example.com')
        end
      end
    end
  end

  describe '#authorize_options' do
    %i[access_type hd login_hint prompt scope state device_id device_name].each do |k|
      it "should support #{k}" do
        @options = { k => 'http://someval' }
        expect(subject.authorize_params[k.to_s]).to eq('http://someval')
      end
    end

    describe 'redirect_uri' do
      it 'should default to nil' do
        @options = {}
        expect(subject.authorize_params['redirect_uri']).to eq(nil)
      end

      it 'should set the redirect_uri parameter if present' do
        @options = { redirect_uri: 'https://example.com' }
        expect(subject.authorize_params['redirect_uri']).to eq('https://example.com')
      end
    end

    describe 'access_type' do
      it 'should default to "offline"' do
        @options = {}
        expect(subject.authorize_params['access_type']).to eq('offline')
      end

      it 'should set the access_type parameter if present' do
        @options = { access_type: 'online' }
        expect(subject.authorize_params['access_type']).to eq('online')
      end
    end

    describe 'hd' do
      it 'should default to nil' do
        expect(subject.authorize_params['hd']).to eq(nil)
      end

      it 'should set the hd (hosted domain) parameter if present' do
        @options = { hd: 'example.com' }
        expect(subject.authorize_params['hd']).to eq('example.com')
      end

      it 'should set the hd parameter and work with nil hd (gmail)' do
        @options = { hd: nil }
        expect(subject.authorize_params['hd']).to eq(nil)
      end

      it 'should set the hd parameter to * if set (only allows G Suite emails)' do
        @options = { hd: '*' }
        expect(subject.authorize_params['hd']).to eq('*')
      end
    end

    describe 'login_hint' do
      it 'should default to nil' do
        expect(subject.authorize_params['login_hint']).to eq(nil)
      end

      it 'should set the login_hint parameter if present' do
        @options = { login_hint: 'john@example.com' }
        expect(subject.authorize_params['login_hint']).to eq('john@example.com')
      end
    end

    describe 'prompt' do
      it 'should default to nil' do
        expect(subject.authorize_params['prompt']).to eq(nil)
      end

      it 'should set the prompt parameter if present' do
        @options = { prompt: 'consent select_account' }
        expect(subject.authorize_params['prompt']).to eq('consent select_account')
      end
    end

    describe 'request_visible_actions' do
      it 'should default to nil' do
        expect(subject.authorize_params['request_visible_actions']).to eq(nil)
      end

      it 'should set the request_visible_actions parameter if present' do
        @options = { request_visible_actions: 'something' }
        expect(subject.authorize_params['request_visible_actions']).to eq('something')
      end
    end

    describe 'include_granted_scopes' do
      it 'should default to nil' do
        expect(subject.authorize_params['include_granted_scopes']).to eq(nil)
      end

      it 'should set the include_granted_scopes parameter if present' do
        @options = { include_granted_scopes: 'true' }
        expect(subject.authorize_params['include_granted_scopes']).to eq('true')
      end
    end

    describe 'enable_granular_consent' do
      it 'should default to nil' do
        expect(subject.authorize_params['enable_granular_consent']).to eq(nil)
      end

      it 'should set the enable_granular_consent parameter if present' do
        @options = { enable_granular_consent: 'true' }
        expect(subject.authorize_params['enable_granular_consent']).to eq('true')
      end
    end

    describe 'scope' do
      it 'should expand scope shortcuts' do
        @options = { scope: 'calendar' }
        expect(subject.authorize_params['scope']).to eq('https://www.googleapis.com/auth/calendar')
      end

      it 'should leave base scopes as is' do
        @options = { scope: 'profile' }
        expect(subject.authorize_params['scope']).to eq('profile')
      end

      it 'should join scopes' do
        @options = { scope: 'profile,email' }
        expect(subject.authorize_params['scope']).to eq('profile email')
      end

      it 'should deal with whitespace when joining scopes' do
        @options = { scope: 'profile, email' }
        expect(subject.authorize_params['scope']).to eq('profile email')
      end

      it 'should set default scope to email,profile' do
        expect(subject.authorize_params['scope']).to eq('email profile')
      end

      it 'should support space delimited scopes' do
        @options = { scope: 'profile email' }
        expect(subject.authorize_params['scope']).to eq('profile email')
      end

      it 'should support extremely badly formed scopes' do
        @options = { scope: 'profile email,foo,steve yeah http://example.com' }
        expect(subject.authorize_params['scope']).to eq('profile email https://www.googleapis.com/auth/foo https://www.googleapis.com/auth/steve https://www.googleapis.com/auth/yeah http://example.com')
      end
    end

    describe 'state' do
      it 'should set the state parameter' do
        @options = { state: 'some_state' }
        expect(subject.authorize_params['state']).to eq('some_state')
        expect(subject.authorize_params[:state]).to eq('some_state')
        expect(subject.session['omniauth.state']).to eq('some_state')
      end

      it 'should set the omniauth.state dynamically' do
        allow(subject).to receive(:request) { double('Request', params: { 'state' => 'some_state' }, env: {}) }
        expect(subject.authorize_params['state']).to eq('some_state')
        expect(subject.authorize_params[:state]).to eq('some_state')
        expect(subject.session['omniauth.state']).to eq('some_state')
      end
    end

    describe 'overrides' do
      it 'should include top-level options that are marked as :authorize_options' do
        @options = { authorize_options: %i[scope foo request_visible_actions], scope: 'http://bar', foo: 'baz', hd: 'wow', request_visible_actions: 'something' }
        expect(subject.authorize_params['scope']).to eq('http://bar')
        expect(subject.authorize_params['foo']).to eq('baz')
        expect(subject.authorize_params['hd']).to eq(nil)
        expect(subject.authorize_params['request_visible_actions']).to eq('something')
      end

      describe 'request overrides' do
        %i[access_type hd login_hint prompt scope state].each do |k|
          context "authorize option #{k}" do
            let(:request) { double('Request', params: { k.to_s => 'http://example.com' }, cookies: {}, env: {}) }

            context 'when overridable_authorize_options is default' do
              it "should set the #{k} authorize option dynamically in the request" do
                @options = { k: '' }
                expect(subject.authorize_params[k.to_s]).to eq('http://example.com')
              end
            end

            context 'when overridable_authorize_options is empty' do
              it "should not set the #{k} authorize option dynamically in the request" do
                @options = { k: '', overridable_authorize_options: [] }
                expect(subject.authorize_params[k.to_s]).not_to eq('http://example.com')
              end
            end
          end
        end

        describe 'custom authorize_options' do
          let(:request) { double('Request', params: { 'foo' => 'something' }, cookies: {}, env: {}) }

          context 'when overridable_authorize_options is default' do
            it 'should not support request overrides from custom authorize_options' do
              @options = { authorize_options: [:foo], foo: '' }
              expect(subject.authorize_params['foo']).not_to eq('something')
            end
          end

          context 'when overridable_authorize_options is customized' do
            it 'should support request overrides from custom authorize_options' do
              @options = { authorize_options: [:foo], overridable_authorize_options: [:foo], foo: '' }
              expect(subject.authorize_params['foo']).to eq('something')
            end
          end
        end
      end
    end
  end

  describe '#authorize_params' do
    it 'should include any authorize params passed in the :authorize_params option' do
      @options = { authorize_params: { request_visible_actions: 'something', foo: 'bar', baz: 'zip' }, hd: 'wow', bad: 'not_included' }
      expect(subject.authorize_params['request_visible_actions']).to eq('something')
      expect(subject.authorize_params['foo']).to eq('bar')
      expect(subject.authorize_params['baz']).to eq('zip')
      expect(subject.authorize_params['hd']).to eq('wow')
      expect(subject.authorize_params['bad']).to eq(nil)
    end
  end

  describe '#token_params' do
    it 'should include any token params passed in the :token_params option' do
      @options = { token_params: { foo: 'bar', baz: 'zip' } }
      expect(subject.token_params['foo']).to eq('bar')
      expect(subject.token_params['baz']).to eq('zip')
    end
  end

  describe '#token_options' do
    it 'should include top-level options that are marked as :token_options' do
      @options = { token_options: %i[scope foo], scope: 'bar', foo: 'baz', bad: 'not_included' }
      expect(subject.token_params['scope']).to eq('bar')
      expect(subject.token_params['foo']).to eq('baz')
      expect(subject.token_params['bad']).to eq(nil)
    end
  end

  describe '#callback_url' do
    let(:base_url) { 'https://example.com' }

    it 'has the correct default callback path' do
      allow(subject).to receive(:full_host) { base_url }
      allow(subject).to receive(:script_name) { '' }
      expect(subject.send(:callback_url)).to eq("#{base_url}/auth/google_oauth2/callback")
    end

    it 'should set the callback path with script_name if present' do
      allow(subject).to receive(:full_host) { base_url }
      allow(subject).to receive(:script_name) { '/v1' }
      expect(subject.send(:callback_url)).to eq("#{base_url}/v1/auth/google_oauth2/callback")
    end

    it 'should set the callback_path parameter if present' do
      @options = { callback_path: '/auth/foo/callback' }
      allow(subject).to receive(:full_host) { base_url }
      allow(subject).to receive(:script_name) { '' }
      expect(subject.send(:callback_url)).to eq("#{base_url}/auth/foo/callback")
    end
  end

  describe '#uid' do
    let(:client) do
      OAuth2::Client.new('abc', 'def') do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v3/userinfo') { [200, { 'content-type' => 'application/json' }, '{"sub": "12345"}'] }
        end
      end
    end
    let(:access_token) { OAuth2::AccessToken.from_hash(client, { 'access_token' => 'a' }) }
    before { allow(subject).to receive(:access_token).and_return(access_token) }

    it 'should return the sub from raw_info as uid' do
      expect(subject.uid).to eq('12345')
    end
  end

  describe '#info' do
    let(:client) do
      OAuth2::Client.new('abc', 'def') do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v3/userinfo') { [200, { 'content-type' => 'application/json' }, response_hash.to_json] }
        end
      end
    end
    let(:access_token) { OAuth2::AccessToken.from_hash(client, { 'access_token' => 'a' }) }
    before { allow(subject).to receive(:access_token).and_return(access_token) }

    context 'with verified email' do
      let(:response_hash) do
        { email: 'something@domain.invalid', email_verified: true }
      end

      it 'should return equal email and unverified_email' do
        expect(subject.info[:email]).to eq('something@domain.invalid')
        expect(subject.info[:unverified_email]).to eq('something@domain.invalid')
      end
    end

    context 'with unverified email' do
      let(:response_hash) do
        { email: 'something@domain.invalid', email_verified: false }
      end

      it 'should return nil email, and correct unverified email' do
        expect(subject.info[:email]).to eq(nil)
        expect(subject.info[:unverified_email]).to eq('something@domain.invalid')
      end
    end
  end

  describe '#credentials' do
    let(:client) { OAuth2::Client.new('abc', 'def') }
    let(:access_token) { OAuth2::AccessToken.from_hash(client, access_token: 'valid_access_token', expires_at: 123_456_789, refresh_token: 'valid_refresh_token') }
    before(:each) do
      allow(subject).to receive(:access_token).and_return(access_token)
      subject.options.client_options[:connection_build] = proc do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.post('/oauth2/v3/tokeninfo', 'access_token=valid_access_token') do
            [200, { 'Content-Type' => 'application/json; charset=UTF-8' }, JSON.dump(
              aud: '000000000000.apps.googleusercontent.com',
              sub: '123456789',
              scope: 'profile email'
            )]
          end
        end
      end
    end

    it 'should return access token and (optionally) refresh token' do
      expect(subject.credentials.to_h).to \
        match(hash_including(
                'token' => 'valid_access_token',
                'refresh_token' => 'valid_refresh_token',
                'scope' => 'profile email',
                'expires_at' => 123_456_789,
                'expires' => true
              ))
    end
  end

  describe '#extra' do
    let(:client) do
      OAuth2::Client.new('abc', 'def') do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v3/userinfo') { [200, { 'content-type' => 'application/json' }, '{"sub": "12345"}'] }
        end
      end
    end
    before { allow(subject).to receive(:access_token).and_return(access_token) }

    describe 'id_token' do
      shared_examples 'id_token issued by valid issuer' do |issuer|
        context 'when the id_token is passed into the access token' do
          let(:token_info) do
            {
              'abc' => 'xyz',
              'exp' => Time.now.to_i + 3600,
              'nbf' => Time.now.to_i - 60,
              'iat' => Time.now.to_i,
              'aud' => 'appid',
              'iss' => issuer
            }
          end
          let(:id_token) { JWT.encode(token_info, 'secret') }
          let(:access_token) do
            OAuth2::AccessToken.from_hash(client, 'access_token' => 'valid_access_token', 'id_token' => id_token)
          end

          it 'should include id_token when set on the access_token' do
            expect(subject.extra).to include(id_token: id_token)
          end

          it 'should include id_info when id_token is set on the access_token and skip_jwt is false' do
            subject.options[:skip_jwt] = false
            expect(subject.extra).to include(id_info: token_info)
          end

          it 'should not include id_info when id_token is set on the access_token and skip_jwt is true' do
            subject.options[:skip_jwt] = true
            expect(subject.extra).not_to have_key(:id_info)
          end

          it 'should include id_info when id_token is set on the access_token by default' do
            expect(subject.extra).to include(id_info: token_info)
          end

          it 'decodes the token only once across repeated extra calls' do
            allow(JWT).to receive(:decode).and_call_original

            2.times { subject.extra }

            expect(JWT).to have_received(:decode).once
          end
        end
      end

      it_behaves_like 'id_token issued by valid issuer', 'accounts.google.com'
      it_behaves_like 'id_token issued by valid issuer', 'https://accounts.google.com'

      context 'when the id_token is issued by an invalid issuer' do
        let(:token_info) do
          {
            'abc' => 'xyz',
            'exp' => Time.now.to_i + 3600,
            'nbf' => Time.now.to_i - 60,
            'iat' => Time.now.to_i,
            'aud' => 'appid',
            'iss' => 'fake.google.com'
          }
        end
        let(:id_token) { JWT.encode(token_info, 'secret') }
        let(:access_token) do
          OAuth2::AccessToken.from_hash(client, 'access_token' => 'valid_access_token', 'id_token' => id_token)
        end

        it 'raises JWT::InvalidIssuerError' do
          expect { subject.extra }.to raise_error(JWT::InvalidIssuerError)
        end
      end

      # Reaching extra without going through verified_id_token, so the claim
      # cache is empty and extra does the audience check itself. This is the
      # multi-platform case: a token minted for a sibling client id.
      context 'when the id_token is minted for an authorized client' do
        let(:token_info) do
          {
            'exp' => Time.now.to_i + 3600,
            'nbf' => Time.now.to_i - 60,
            'iat' => Time.now.to_i,
            'aud' => 'android-client-id',
            'iss' => 'https://accounts.google.com'
          }
        end
        let(:id_token) { JWT.encode(token_info, 'secret') }
        let(:access_token) do
          OAuth2::AccessToken.from_hash(client, 'access_token' => 'valid_access_token', 'id_token' => id_token)
        end

        it 'decodes it when that client is configured' do
          # Built here rather than through `subject`, because the enclosing
          # before hook instantiates the strategy before an example body runs.
          strategy = described_class.new(app, 'appid', 'secret', authorized_client_ids: ['android-client-id'])
          allow(strategy).to receive_messages(request: request, access_token: access_token)

          expect(strategy.extra[:id_info]).to include('aud' => 'android-client-id')
        end

        it 'rejects it when that client is not configured' do
          expect { subject.extra }.to raise_error(JWT::InvalidAudError)
        end
      end

      context 'when the access token is empty or nil' do
        let(:access_token) { OAuth2::AccessToken.new(client, nil, { 'refresh_token' => 'foo' }) }

        it 'should not include id_token' do
          expect(subject.extra).not_to have_key(:id_token)
        end

        it 'should not include id_info' do
          expect(subject.extra).not_to have_key(:id_info)
        end
      end

      context 'when the access token does not include an id_token' do
        let(:access_token) { OAuth2::AccessToken.from_hash(client, 'access_token' => 'opaque_access_token') }

        it 'does not treat the opaque access token as an id_token' do
          expect(subject.extra).not_to include(:id_token, :id_info)
        end
      end
    end

    describe 'raw_info' do
      let(:token_info) do
        {
          'abc' => 'xyz',
          'exp' => Time.now.to_i + 3600,
          'nbf' => Time.now.to_i - 60,
          'iat' => Time.now.to_i,
          'aud' => 'appid',
          'iss' => 'accounts.google.com'
        }
      end
      let(:id_token) { JWT.encode(token_info, 'secret') }
      let(:access_token) { OAuth2::AccessToken.from_hash(client, 'id_token' => id_token) }

      context 'when skip_info is true' do
        before { subject.options[:skip_info] = true }

        it 'should not include raw_info' do
          expect(subject.extra).not_to have_key(:raw_info)
        end
      end

      context 'when skip_info is false' do
        before { subject.options[:skip_info] = false }

        it 'should include raw_info' do
          expect(subject.extra[:raw_info]).to eq('sub' => '12345')
        end
      end
    end
  end

  describe 'populate auth hash urls' do
    it 'should populate url map in auth hash if link present in raw_info' do
      allow(subject).to receive(:raw_info) { { 'name' => 'Foo', 'profile' => 'https://plus.google.com/123456' } }
      expect(subject.info[:urls][:google]).to eq('https://plus.google.com/123456')
    end

    it 'should not populate url map in auth hash if no link present in raw_info' do
      allow(subject).to receive(:raw_info) { { 'name' => 'Foo' } }
      expect(subject.info).not_to have_key(:urls)
    end
  end

  describe 'image options' do
    it 'should have no image if a picture is not present' do
      @options = { image_aspect_ratio: 'square' }
      allow(subject).to receive(:raw_info) { { 'name' => 'User Without Pic' } }
      expect(subject.info[:image]).to be_nil
    end

    describe 'when a picture is returned from google' do
      it 'should return the image with size specified in the `image_size` option' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50')
      end

      it 'should return the image with size specified in the `image_size` option when sizing is in the picture' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s96' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50')
      end

      it 'should return the image with size specified in the `image_size` option when sizing is in the picture and cropped' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s96-c' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50')
      end

      it 'should handle a picture with too many slashes' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a//ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50')
      end

      it 'should handle a picture with a size query parameter' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0?sz=96' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50')
      end

      it 'should handle a picture with a size query parameter and sizing is in the picture' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s96-c?sz=96' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50')
      end

      it 'should handle a picture with a size query parameter and other valid query parameters correctly' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0?sz=50&hello=true&life=42' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50?hello=true&life=42')
      end

      it 'should handle a picture with a size query parameter, other valid query parameters and sizing is in the picture correctly' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s96-c?sz=50&hello=true&life=42' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50?hello=true&life=42')
      end

      it 'should handle a picture with other valid query parameters correctly' do
        @options = { image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0?hello=true&life=42' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50?hello=true&life=42')
      end

      it 'should return the image with width and height specified in the `image_size` option' do
        @options = { image_size: { width: 50, height: 40 } }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w50-h40')
      end

      it 'should return the image with width and height specified in the `image_size` option when sizing is in the picture' do
        @options = { image_size: { width: 50, height: 40 } }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w100-h80-c' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w50-h40')
      end

      it 'should return square image when square `image_aspect_ratio` is specified' do
        @options = { image_aspect_ratio: 'square' }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=c')
      end

      it 'should return square image when square `image_aspect_ratio` is specified and sizing is in the picture' do
        @options = { image_aspect_ratio: 'square' }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50-c' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=c')
      end

      it 'should return smart image when smart `image_aspect_ratio` is specified' do
        @options = { image_aspect_ratio: 'smart' }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=p')
      end

      it 'should return smart image when smart `image_aspect_ratio` is specified and sizing is in the picture' do
        @options = { image_aspect_ratio: 'smart' }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50-c' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=p')
      end

      it 'should return square sized image when square `image_aspect_ratio` and `image_size` is set' do
        @options = { image_aspect_ratio: 'square', image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50-c')
      end

      it 'should return square sized image when square `image_aspect_ratio` and `image_size` is set and sizing is in the picture' do
        @options = { image_aspect_ratio: 'square', image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s90' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50-c')
      end

      it 'should return smart sized image when smart `image_aspect_ratio` and `image_size` is set' do
        @options = { image_aspect_ratio: 'smart', image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50-p')
      end

      it 'should return smart sized image when smart `image_aspect_ratio` and `image_size` is set and sizing is in the picture' do
        @options = { image_aspect_ratio: 'smart', image_size: 50 }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s90' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=s50-p')
      end

      it 'should return square sized image when square `image_aspect_ratio` and `image_size` has height and width' do
        @options = { image_aspect_ratio: 'square', image_size: { width: 50, height: 40 } }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w50-h40-c')
      end

      it 'should return square sized image when square `image_aspect_ratio` and `image_size` has height and width and sizing is in the picture' do
        @options = { image_aspect_ratio: 'square', image_size: { width: 50, height: 40 } }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w100-h80-c' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w50-h40-c')
      end

      it 'should return smart sized image when smart `image_aspect_ratio` and `image_size` has height and width' do
        @options = { image_aspect_ratio: 'smart', image_size: { width: 50, height: 40 } }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w50-h40-p')
      end

      it 'should return smart sized image when smart `image_aspect_ratio` and `image_size` has height and width and sizing is in the picture' do
        @options = { image_aspect_ratio: 'smart', image_size: { width: 50, height: 40 } }
        allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w100-h80-c' } }
        expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0=w50-h40-p')
      end
    end

    it 'should return original image if no options are provided' do
      allow(subject).to receive(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0' } }
      expect(subject.info[:image]).to eq('https://lh3.googleusercontent.com/a/ACg8ocKN8F32STvmW-LG0Rl_9re5-Pv2cCn0ayodas6BQFPGEArMOtn0')
    end
  end

  describe 'strip_unnecessary_query_parameters' do
    it 'should return nil when query_parameters is nil' do
      expect(subject.send(:strip_unnecessary_query_parameters, nil)).to be_nil
    end

    it 'should return nil when sz is the only parameter' do
      expect(subject.send(:strip_unnecessary_query_parameters, 'sz=50')).to be_nil
    end

    it 'should strip sz and return remaining parameters' do
      expect(subject.send(:strip_unnecessary_query_parameters, 'sz=50&hello=true&life=42')).to eq('hello=true&life=42')
    end

    it 'should return all parameters when sz is not present' do
      expect(subject.send(:strip_unnecessary_query_parameters, 'hello=true&life=42')).to eq('hello=true&life=42')
    end
  end

  describe 'build_access_token' do
    # Stands in for what the token endpoint really hands back; a bare stub would
    # return nil, which the strategy now rejects as "no credential".
    let(:stubbed_token) { double('AccessToken') }

    # Mimics a Rack 3 input stream: readable, but deliberately not rewindable.
    # A strict double fails the example if anything calls rewind on it.
    def non_rewindable_input(content)
      io = StringIO.new(content)
      double('Rack3Input').tap do |input|
        allow(input).to receive(:read) { |*args| io.read(*args) }
        allow(input).to receive(:gets) { io.gets }
        allow(input).to receive(:each) { |&block| io.each(&block) }
      end
    end

    it 'should use a hybrid authorization request_uri if this is an AJAX request with a code parameter' do
      allow(request).to receive(:xhr?).and_return(true)
      allow(request).to receive(:params).and_return('code' => 'valid_code')

      client = double(:client)
      auth_code = double(:auth_code)
      allow(client).to receive(:auth_code).and_return(auth_code)
      expect(subject).to receive(:client).and_return(client)
      expect(auth_code).to receive(:get_token).with('valid_code', { redirect_uri: 'postmessage' }, {}).and_return(stubbed_token)

      subject.build_access_token
    end

    it 'should use a hybrid authorization request_uri if this is an AJAX request (mobile) with a code parameter' do
      allow(request).to receive(:xhr?).and_return(true)
      allow(request).to receive(:params).and_return('code' => 'valid_code', 'redirect_uri' => '')

      client = double(:client)
      auth_code = double(:auth_code)
      allow(client).to receive(:auth_code).and_return(auth_code)
      expect(subject).to receive(:client).and_return(client)
      expect(auth_code).to receive(:get_token).with('valid_code', { redirect_uri: '' }, {}).and_return(stubbed_token)

      subject.build_access_token
    end

    it 'should use the request_uri from params if this not an AJAX request (request from installed app) with a code parameter' do
      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:params).and_return('code' => 'valid_code', 'redirect_uri' => 'redirect_uri')

      client = double(:client)
      auth_code = double(:auth_code)
      allow(client).to receive(:auth_code).and_return(auth_code)
      expect(subject).to receive(:client).and_return(client)
      expect(auth_code).to receive(:get_token).with('valid_code', { redirect_uri: 'redirect_uri' }, {}).and_return(stubbed_token)

      subject.build_access_token
    end

    it 'should read only access_token from params if this is not an AJAX request with a code parameter' do
      client = OAuth2::Client.new('abc', 'def') do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v3/userinfo') { [200, { 'content-type' => 'application/json' }, '{"sub": "12345"}'] }
        end
      end

      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:params).and_return(
        'access_token' => 'valid_access_token',
        'id_token' => 'forged_id_token',
        'refresh_token' => 'forged_refresh_token',
        'expires_at' => 123_456_789
      )
      expect(subject).to receive(:verify_token).with('valid_access_token').and_return true
      expect(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:warn)

      token = subject.build_access_token
      expect(token).to be_instance_of(OAuth2::AccessToken)
      expect(token.token).to eq('valid_access_token')
      expect(token.client).to eq(client)
      expect(token.params).to be_empty
      expect(token.refresh_token).to be_nil
      expect(token.expires_at).to be_nil
    end

    it 'reads the code from a json request body' do
      # Literal UTF-8 rather than JSON.dump, which would escape the accent back to ASCII.
      payload = %({"code":"json_access_token","note":"café"})
      body = non_rewindable_input(payload)
      client = double(:client)
      auth_code = double(:auth_code)

      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:content_type).and_return('application/json')
      allow(request).to receive(:body).and_return(body)
      allow(client).to receive(:auth_code).and_return(auth_code)
      expect(subject).to receive(:client).and_return(client)

      expect(auth_code).to receive(:get_token).with('json_access_token', { redirect_uri: 'postmessage' }, {}).and_return(stubbed_token)

      subject.build_access_token

      expect(request.env['rack.input']).to be_a(StringIO)
      expect(request.env['rack.input'].read.b).to eq(payload.b)
    end

    it 'reads the redirect uri from a json request body' do
      body = StringIO.new(%({"code":"json_access_token", "redirect_uri":"sample"}))
      client = double(:client)
      auth_code = double(:auth_code)

      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:content_type).and_return('application/json')
      allow(request).to receive(:body).and_return(body)
      allow(client).to receive(:auth_code).and_return(auth_code)
      expect(subject).to receive(:client).and_return(client)

      expect(auth_code).to receive(:get_token).with('json_access_token', { redirect_uri: 'sample' }, {}).and_return(stubbed_token)

      subject.build_access_token
    end

    it 'reads only the access token from a json request body' do
      body = StringIO.new(JSON.dump(
                            access_token: 'valid_access_token',
                            id_token: 'forged_id_token',
                            refresh_token: 'forged_refresh_token',
                            expires_at: 123_456_789
                          ))
      client = OAuth2::Client.new('abc', 'def') do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v3/userinfo') { [200, { 'content-type' => 'application/json' }, '{"sub": "12345"}'] }
        end
      end

      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:content_type).and_return('application/json')
      allow(request).to receive(:body).and_return(body)
      expect(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:warn)

      expect(subject).to receive(:verify_token).with('valid_access_token').and_return true

      token = subject.build_access_token
      expect(token).to be_instance_of(OAuth2::AccessToken)
      expect(token.token).to eq('valid_access_token')
      expect(token.client).to eq(client)
      expect(token.params).to be_empty
      expect(token.refresh_token).to be_nil
      expect(token.expires_at).to be_nil
    end

    it 'should handle a malformed json request body gracefully' do
      payload = 'not valid json{{{'
      body = non_rewindable_input(payload)

      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:params).and_return({})
      allow(request).to receive(:content_type).and_return('application/json')
      allow(request).to receive(:body).and_return(body)

      # Warns about the body, then fails as a normal auth failure rather than
      # handing a nil token to the caller.
      expect do
        expect { subject.build_access_token }.to raise_error(OmniAuth::Strategies::OAuth2::CallbackError)
      end.to output(/JSON parse error/).to_stderr

      # The body is restored for downstream middlewares even when parsing fails.
      expect(request.env['rack.input'].read.b).to eq(payload.b)
    end

    it 'fails cleanly when the request carries no usable credential' do
      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:params).and_return('id_token' => 'an-id-token-with-no-access-token')
      allow(request).to receive(:content_type).and_return(nil)

      # The reason matters: verify_hd raises the same class, and applications
      # branch on the message OmniAuth puts in the failure redirect.
      expect { subject.build_access_token }.to raise_error(
        OmniAuth::Strategies::OAuth2::CallbackError, /invalid_credentials.*No valid credentials/
      )
    end

    [['a JSON array', '[1,2,3]'], ['a JSON number', '42'], ['a JSON string', '"nope"']].each do |label, payload|
      it "fails cleanly when the JSON body is #{label} rather than an object" do
        allow(request).to receive(:xhr?).and_return(false)
        allow(request).to receive(:params).and_return({})
        allow(request).to receive(:content_type).and_return('application/json')
        allow(request).to receive(:body).and_return(non_rewindable_input(payload))

        # Indexing a non-Hash by string would raise TypeError out of the callback.
        expect { subject.build_access_token }.to raise_error(OmniAuth::Strategies::OAuth2::CallbackError)
      end
    end

    it 'should use callback_url without query_string if this is not an AJAX request' do
      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:params).and_return('code' => 'valid_code')
      allow(request).to receive(:content_type).and_return('application/x-www-form-urlencoded')

      client = double(:client)
      auth_code = double(:auth_code)
      allow(client).to receive(:auth_code).and_return(auth_code)
      allow(subject).to receive(:callback_url).and_return('redirect_uri_without_query_string')

      expect(subject).to receive(:client).and_return(client)
      expect(auth_code).to receive(:get_token).with('valid_code', { redirect_uri: 'redirect_uri_without_query_string' }, {}).and_return(stubbed_token)
      subject.build_access_token
    end
  end

  describe 'client-supplied id_token verification' do
    # Generated once: RSA keygen is slow and the key is immutable across examples.
    signing_key = OpenSSL::PKey::RSA.generate(2048)

    # Exposed through a let so the helper methods below can reach it; a bare
    # local is out of scope inside a def.
    let(:key) { signing_key }
    let(:jwks_status) { 200 }
    let(:jwks_body) do
      JSON.dump('keys' => [JWT::JWK.new(key, { kid: 'test-key', use: 'sig', alg: 'RS256' }).export])
    end
    let(:claims) do
      { 'iss' => 'https://accounts.google.com', 'aud' => 'appid', 'sub' => '12345',
        'email' => 'john@example.com', 'email_verified' => true,
        'exp' => Time.now.to_i + 3600, 'nbf' => Time.now.to_i - 60 }
    end
    let(:genuine_id_token) { signed(claims) }
    let(:jwks_response) { jwks_body }
    let(:client) do
      OAuth2::Client.new('appid', 'secret', site: 'https://www.googleapis.com') do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v3/certs') do
            jwks_status == 200 ? [200, { 'content-type' => 'application/json' }, jwks_response] : [jwks_status, {}, 'upstream error']
          end
          stub.get('/oauth2/v3/userinfo') { [200, { 'content-type' => 'application/json' }, '{"sub":"12345"}'] }
        end
      end
    end

    def signed(payload)
      JWT.encode(payload, key, 'RS256', { kid: 'test-key' })
    end

    def build_token(id_token)
      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:params).and_return(
        'access_token' => 'valid_access_token', 'id_token' => id_token,
        'refresh_token' => 'forged_refresh_token', 'expires_at' => 123_456_789
      )
      allow(subject).to receive(:verify_token).with('valid_access_token').and_return(true)
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:warn)
      subject.build_access_token
    end

    it 'keeps an id_token that Google actually signed' do
      expect(build_token(genuine_id_token)['id_token']).to eq(genuine_id_token)
    end

    it 'exposes the verified claims as id_info' do
      subject.access_token = build_token(genuine_id_token)
      expect(subject.extra[:id_info]['email']).to eq('john@example.com')
    end

    it 'decodes a caller-supplied id_token only once' do
      allow(JWT).to receive(:decode).and_call_original

      subject.access_token = build_token(genuine_id_token)
      subject.extra

      expect(JWT).to have_received(:decode).once
    end

    it 'does not revalidate a caller-supplied id_token during extra processing' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      expiring = signed(claims.merge('exp' => now.to_i + 1))
      subject.access_token = build_token(expiring)

      allow(Time).to receive(:now).and_return(now + 3600)

      expect(subject.extra[:id_info]).to include('sub' => '12345')
    end

    it 'keeps an id_token minted for an authorized client' do
      subject.options.authorized_client_ids = ['mobile-client']
      authorized = signed(claims.merge('aud' => 'mobile-client'))

      subject.access_token = build_token(authorized)

      expect(subject.extra).to include(
        id_token: authorized,
        id_info: hash_including('aud' => 'mobile-client')
      )
    end

    it 'keeps an authorized-client id_token when JWT output is skipped' do
      subject.options.authorized_client_ids = ['mobile-client']
      subject.options.skip_jwt = true
      authorized = signed(claims.merge('aud' => 'mobile-client'))

      subject.access_token = build_token(authorized)

      expect(subject.extra).to include(id_token: authorized)
      expect(subject.extra).not_to have_key(:id_info)
    end

    # These carry a kid that IS in the key set, so they reach the algorithm check
    # rather than being turned away earlier at key lookup. Without the kid they
    # would pass even if the RS256 pin were removed.
    it 'discards an unsigned id_token' do
      forged = JWT.encode(claims.merge('email' => 'victim@example.com'), nil, 'none', { kid: 'test-key' })
      expect(build_token(forged)['id_token']).to be_nil
    end

    it 'discards an id_token signed with a symmetric algorithm' do
      forged = JWT.encode(claims.merge('email' => 'victim@example.com'), 'guessed-secret', 'HS256', { kid: 'test-key' })
      expect(build_token(forged)['id_token']).to be_nil
    end

    it 'discards an id_token signed with the public key as an HMAC secret' do
      forged = JWT.encode(claims.merge('email' => 'victim@example.com'), key.public_key.to_pem, 'HS256', { kid: 'test-key' })
      expect(build_token(forged)['id_token']).to be_nil
    end

    it 'discards an id_token that is not yet valid' do
      expect(build_token(signed(claims.merge('nbf' => Time.now.to_i + 3600)))['id_token']).to be_nil
    end

    it 'discards an id_token signed by an unknown key' do
      stranger = OpenSSL::PKey::RSA.generate(2048)
      forged = JWT.encode(claims, stranger, 'RS256', { kid: 'test-key' })
      expect(build_token(forged)['id_token']).to be_nil
    end

    it 'discards an id_token minted for another audience' do
      expect(build_token(signed(claims.merge('aud' => 'someone-elses-app')))['id_token']).to be_nil
    end

    it 'discards an id_token from an untrusted issuer' do
      expect(build_token(signed(claims.merge('iss' => 'https://evil.example.com')))['id_token']).to be_nil
    end

    it 'discards an expired id_token' do
      expect(build_token(signed(claims.merge('exp' => Time.now.to_i - 3600)))['id_token']).to be_nil
    end

    it 'refetches the key set when a token names a key it does not hold' do
      # Exercised through a real id_token rather than by calling the cache
      # directly, so the wiring from the decoder's invalidate hook is covered:
      # without it a rotated Google key would never be picked up.
      fetches = 0
      counting_client = OAuth2::Client.new('appid', 'secret', site: 'https://www.googleapis.com') do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v3/certs') do
            fetches += 1
            [200, { 'content-type' => 'application/json' }, jwks_body]
          end
          stub.get('/oauth2/v3/userinfo') { [200, { 'content-type' => 'application/json' }, '{"sub":"12345"}'] }
        end
      end

      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:params).and_return(
        'access_token' => 'valid_access_token',
        'id_token' => JWT.encode(claims, key, 'RS256', { kid: 'rotated-key' })
      )
      allow(subject).to receive(:verify_token).with('valid_access_token').and_return(true)
      allow(subject).to receive_messages(client: counting_client, warn: nil)

      subject.build_access_token

      expect(fetches).to eq(2)
    end

    it 'still discards request-supplied refresh_token and expiry' do
      token = build_token(genuine_id_token)
      expect(token.refresh_token).to be_nil
      expect(token.expires_at).to be_nil
    end

    # Precomputed with Base64.urlsafe_encode64 over 'valid_access_token' and
    # 'another_access_token', pinning the strategy's pack-based encoding against
    # an independent implementation. The userinfo stub above reports sub 12345,
    # which is the subject the claims carry.
    let(:at_hash_of_access_token) { 'CD6l-YB7vlH5uyYrxoiQtg' }
    let(:at_hash_of_other_token) { 'ThOh39PmYAiHJ-oJozGU7A' }

    it 'keeps an id_token whose at_hash matches the access token' do
      bound = signed(claims.merge('at_hash' => at_hash_of_access_token))
      expect(build_token(bound)['id_token']).to eq(bound)
    end

    # The example above cannot tell whether at_hash or the subject check accepted
    # the token, because both agree. Here they disagree: a matching at_hash proves
    # the pair was issued together, so it decides alone and userinfo is not
    # consulted. Any error in the digest, its length, or its encoding fails this.
    it 'accepts a matching at_hash on its own, without consulting userinfo' do
      bound = signed(claims.merge('sub' => 'a-different-subject', 'at_hash' => at_hash_of_access_token))
      expect(subject).not_to receive(:userinfo_for)

      expect(build_token(bound)['id_token']).to eq(bound)
    end

    it 'keeps an id_token for the same user whose at_hash is stale' do
      # A client that refreshed its access token but forwarded the id_token it
      # was originally issued. Same person, so the subject check carries it.
      skewed = signed(claims.merge('at_hash' => at_hash_of_other_token))
      expect(build_token(skewed)['id_token']).to eq(skewed)
    end

    it 'discards an id_token for a different user than the access token' do
      impostor = signed(claims.merge('sub' => 'someone-else', 'at_hash' => at_hash_of_other_token))
      expect(build_token(impostor)['id_token']).to be_nil
    end

    it 'discards an id_token for a different user even with no at_hash to check' do
      impostor = signed(claims.merge('sub' => 'someone-else'))
      # Decoded, because `impostor` is the encoded JWT string and a plain
      # include? on it would be a substring check over base64 text.
      expect(JWT.decode(impostor, nil, false).first).not_to have_key('at_hash')
      expect(build_token(impostor)['id_token']).to be_nil
    end

    it 'keeps a genuine id_token that carries no at_hash' do
      expect(claims).not_to have_key('at_hash')
      expect(build_token(genuine_id_token)['id_token']).to eq(genuine_id_token)
    end

    it 'checks the subject even when skip_info is set' do
      @options = { skip_info: true }
      impostor = signed(claims.merge('sub' => 'someone-else'))
      expect(build_token(impostor)['id_token']).to be_nil
    end

    it 'discards the id_token when userinfo cannot be reached' do
      allow_any_instance_of(OAuth2::AccessToken).to receive(:get).and_raise(OAuth2::Error.new(double(parsed: {}, body: '', headers: {}, status: 500)))
      expect { build_token(genuine_id_token) }.not_to raise_error
      expect(build_token(genuine_id_token)['id_token']).to be_nil
    end

    it 'verifies id_tokens for subclassed strategies too' do
      subclass = Class.new(OmniAuth::Strategies::GoogleOauth2)
      strategy = subclass.new(app, 'appid', 'secret').tap do |s|
        allow(s).to receive(:request).and_return(request)
        allow(s).to receive(:verify_token).with('valid_access_token').and_return(true)
        allow(s).to receive(:client).and_return(client)
      end
      allow(request).to receive(:xhr?).and_return(false)
      allow(request).to receive(:params).and_return(
        'access_token' => 'valid_access_token', 'id_token' => genuine_id_token
      )

      expect(strategy.build_access_token['id_token']).to eq(genuine_id_token)
    end

    context 'when the key set cannot be fetched' do
      let(:jwks_status) { 500 }

      it 'discards the id_token rather than raising' do
        expect { build_token(genuine_id_token) }.not_to raise_error
      end

      # The load-bearing assertion: an unreachable key set must never mean the
      # token is taken on trust. Without this, failing open is invisible here.
      it 'does not fall back to trusting an unverified id_token' do
        expect(build_token(genuine_id_token)['id_token']).to be_nil
      end

      it 'still returns a usable access token' do
        expect(build_token(genuine_id_token).token).to eq('valid_access_token')
      end
    end

    # JWT::JWK::Set will build a key set out of surprising input rather than
    # refusing it, including an HMAC key from a bare string, so the shape is
    # checked before it gets there.
    # The reason is asserted, not just the outcome: a malformed key set makes the
    # token unverifiable whatever we do, so only the diagnostic distinguishes
    # rejecting the shape from stumbling into a confusing error further down.
    {
      'a JSON array' => ['[1,2,3]', /not an object/],
      'a JSON scalar' => ['42', /not an object/],
      'an object with no keys entry' => ['{"nope":true}', /no keys array/],
      'an object whose keys entry is a string' => ['{"keys":"nope"}', /no keys array/],
      'a body that is not JSON at all' => ['<html>502 Bad Gateway</html>', /JSON::ParserError/]
    }.each do |label, (malformed, reason)|
      context "when the key set response is #{label}" do
        let(:jwks_response) { malformed }

        it 'discards the id_token and reports why' do
          expect { build_token(genuine_id_token) }.not_to raise_error
          expect(build_token(genuine_id_token)['id_token']).to be_nil
          expect(subject).to have_received(:warn).with(reason).at_least(:once)
        end
      end
    end
  end

  describe 'JWKS retrieval' do
    it 'refetches when a token names a key it does not hold' do
      # Key rotation has to resolve, so the first unknown kid forces a refresh.
      attempts = 0
      fetch = -> { attempts += 1 and :key_set }
      described_class.cached_jwks(&fetch)
      described_class.cached_jwks(force: true, &fetch)

      expect(attempts).to eq(2)
    end

    it 'throttles forced refetches so unknown kids cannot drive them' do
      # The sender picks the kid, so an unthrottled force is a way to make the
      # process fetch on demand while holding the lock.
      attempts = 0
      fetch = -> { attempts += 1 and :key_set }
      described_class.cached_jwks(&fetch)
      10.times { described_class.cached_jwks(force: true, &fetch) }

      expect(attempts).to eq(2)
    end

    it 'clears every piece of cached state on reset' do
      described_class.cached_jwks { :key_set }
      described_class.reset_jwks_cache!

      %i[@jwks @jwks_expires_at @jwks_retry_at @jwks_forced_at].each do |ivar|
        expect(described_class.instance_variable_get(ivar)).to be_nil
      end
    end

    it 'backs off after a failed fetch even with nothing cached' do
      attempts = 0
      3.times do
        expect do
          described_class.cached_jwks do
            attempts += 1
            raise described_class::JwksUnavailable
          end
        end.to raise_error(described_class::JwksUnavailable)
      end

      expect(attempts).to eq(1)
    end

    it 'serves the stale key set and backs off when a refresh fails' do
      described_class.cached_jwks { :cached_key_set }
      described_class.instance_variable_set(:@jwks_expires_at, Time.now.to_i - 1)

      attempts = 0
      served = described_class.cached_jwks do
        attempts += 1
        raise SocketError, 'key endpoint unreachable'
      end

      expect(served).to eq(:cached_key_set)
      expect(attempts).to eq(1)
    end

    it 'raises rather than returning nothing when the first fetch fails' do
      expect { described_class.cached_jwks { raise SocketError, 'down at boot' } }
        .to raise_error(SocketError)
    end
  end

  describe 'verify_token' do
    before(:each) do
      subject.options.client_options[:connection_build] = proc do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.post('/oauth2/v3/tokeninfo', 'access_token=valid_access_token') do
            [200, { 'Content-Type' => 'application/json; charset=UTF-8' }, JSON.dump(
              aud: '000000000000.apps.googleusercontent.com',
              sub: '123456789',
              email_verified: 'true',
              email: 'example@example.com',
              access_type: 'offline',
              scope: 'profile email',
              expires_in: 436
            )]
          end
          stub.post('/oauth2/v3/tokeninfo', 'access_token=invalid_access_token') do
            [400, { 'Content-Type' => 'application/json; charset=UTF-8' }, JSON.dump(error_description: 'Invalid Value')]
          end
        end
      end
    end

    it 'should verify token if access_token is valid and app_id equals' do
      subject.options.client_id = '000000000000.apps.googleusercontent.com'
      expect(subject.send(:verify_token, 'valid_access_token')).to eq(true)
    end

    it 'should verify token if access_token is valid and app_id authorized' do
      subject.options.authorized_client_ids = ['000000000000.apps.googleusercontent.com']
      expect(subject.send(:verify_token, 'valid_access_token')).to eq(true)
    end

    it 'should not verify token if access_token is valid but app_id is false' do
      expect(subject.send(:verify_token, 'valid_access_token')).to eq(false)
    end

    it 'should return false if access_token is nil' do
      expect(subject.send(:verify_token, nil)).to eq(false)
    end

    it 'should raise error if access_token is invalid' do
      expect do
        subject.send(:verify_token, 'invalid_access_token')
      end.to raise_error(OAuth2::Error)
    end
  end

  describe 'verify_hd' do
    let(:client) do
      OAuth2::Client.new('abc', 'def') do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v3/userinfo') do
            [200, { 'Content-Type' => 'application/json; charset=UTF-8' }, JSON.dump(
              hd: 'example.com'
            )]
          end
        end
      end
    end
    let(:access_token) { OAuth2::AccessToken.from_hash(client, { 'access_token' => 'foo' }) }

    context 'when domain is nil' do
      let(:client) do
        OAuth2::Client.new('abc', 'def') do |builder|
          builder.request :url_encoded
          builder.adapter :test do |stub|
            stub.get('/oauth2/v3/userinfo') do
              [200, { 'Content-Type' => 'application/json; charset=UTF-8' }, JSON.dump({})]
            end
          end
        end
      end

      it 'should verify hd if options hd is set and correct' do
        subject.options.hd = nil
        expect(subject.send(:verify_hd, access_token)).to eq(true)
      end

      it 'should verify hd if options hd is set as an array and is correct' do
        subject.options.hd = ['example.com', 'example.co', nil]
        expect(subject.send(:verify_hd, access_token)).to eq(true)
      end

      it 'should raise an exception if nil is not included' do
        subject.options.hd = ['example.com', 'example.co']
        expect do
          subject.send(:verify_hd, access_token)
        end.to raise_error(OmniAuth::Strategies::OAuth2::CallbackError)
      end
    end

    it 'should verify hd if options hd is not set' do
      expect(subject.send(:verify_hd, access_token)).to eq(true)
    end

    it 'should verify hd if options hd is set and correct' do
      subject.options.hd = 'example.com'
      expect(subject.send(:verify_hd, access_token)).to eq(true)
    end

    it 'should verify hd if options hd is set as an array and is correct' do
      subject.options.hd = ['example.com', 'example.co', nil]
      expect(subject.send(:verify_hd, access_token)).to eq(true)
    end

    it 'should verify hd if options hd is set as an Proc and is correct' do
      subject.options.hd = proc { 'example.com' }
      expect(subject.send(:verify_hd, access_token)).to eq(true)
    end

    it 'should verify hd if options hd is set as an Proc returning an array and is correct' do
      subject.options.hd = proc { ['example.com', 'example.co'] }
      expect(subject.send(:verify_hd, access_token)).to eq(true)
    end

    it 'should raise error if options hd is set and wrong' do
      subject.options.hd = 'invalid.com'
      expect do
        subject.send(:verify_hd, access_token)
      end.to raise_error(OmniAuth::Strategies::GoogleOauth2::CallbackError)
    end

    it 'should raise error if options hd is set as an array and is not correct' do
      subject.options.hd = ['invalid.com', 'invalid.co']
      expect do
        subject.send(:verify_hd, access_token)
      end.to raise_error(OmniAuth::Strategies::GoogleOauth2::CallbackError)
    end

    it 'should verify hd if options hd is set to wildcard *' do
      subject.options.hd = '*'
      expect(subject.send(:verify_hd, access_token)).to eq(true)
    end
  end
end
