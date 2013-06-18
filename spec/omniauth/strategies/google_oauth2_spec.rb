require 'spec_helper'
require 'omniauth-google-oauth2'

describe OmniAuth::Strategies::GoogleOauth2 do
  def app; lambda{|env| [200, {}, ["Hello."]]} end

  before :each do
    OmniAuth.config.test_mode = true
    @request = double('Request')
    @request.stub(:params) { {} }
    @request.stub(:cookies) { {} }
    @request.stub(:env) { {} }
  end

  after do
    OmniAuth.config.test_mode = false
  end

  subject do
    args = ['appid', 'secret', @options || {}].compact
    OmniAuth::Strategies::GoogleOauth2.new(app, *args).tap do |strategy|
      strategy.stub(:request) { @request }
    end
  end

  it_should_behave_like 'an oauth2 strategy'

  describe '#client' do
    it 'has correct Google site' do
      subject.client.site.should eq('https://accounts.google.com')
    end

    it 'has correct authorize url' do
      subject.client.options[:authorize_url].should eq('/o/oauth2/auth')
    end

    it 'has correct token url' do
      subject.client.options[:token_url].should eq('/o/oauth2/token')
    end
  end

  describe '#callback_path' do
    it 'has the correct callback path' do
      subject.callback_path.should eq('/auth/google_oauth2/callback')
    end
  end

  describe '#authorize_params' do
    %w(access_type hd prompt state any_other).each do |k|
      it "should set the #{k} authorize option dynamically in the request" do
        @options = {:authorize_options => [k.to_sym], k.to_sym => ''}
        subject.stub(:request) { double('Request', {:params => { k => 'something' }, :env => {}}) }
        subject.authorize_params[k].should eq('something')
      end
    end

    describe 'scope' do
      it 'should expand scope shortcuts' do
        @options = { :authorize_options => [:scope], :scope => 'userinfo.email'}
        subject.authorize_params['scope'].should eq('https://www.googleapis.com/auth/userinfo.email')
      end

      it 'should leave full scopes as is' do
        @options = { :authorize_options => [:scope], :scope => 'https://www.googleapis.com/auth/userinfo.profile'}
        subject.authorize_params['scope'].should eq('https://www.googleapis.com/auth/userinfo.profile')
      end

      it 'should join scopes' do
        @options = { :authorize_options => [:scope], :scope => 'userinfo.profile,userinfo.email'}
        subject.authorize_params['scope'].should eq('https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email')
      end

      it 'should deal with whitespace when joining scopes' do
        @options = { :authorize_options => [:scope], :scope => 'userinfo.profile, userinfo.email'}
        subject.authorize_params['scope'].should eq('https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email')
      end

      it 'should set default scope to userinfo.email,userinfo.profile' do
        @options = { :authorize_options => [:scope]}
        subject.authorize_params['scope'].should eq('https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile')
      end

      it 'should dynamically set the scope in the request' do
        @options = {:scope => 'http://example.com'}
        subject.stub(:request) { double('Request', {:params => { 'scope' => 'userinfo.email' }, :env => {}}) }
        subject.authorize_params['scope'].should eq('https://www.googleapis.com/auth/userinfo.email')
      end
    end

    describe 'prompt' do
      it 'should set the prompt parameter if present' do
        @options = {:prompt => 'consent select_account'}
        subject.authorize_params['prompt'].should eq('consent select_account')
      end
    end

    describe 'access_type' do
      it 'should set the access_type parameter if present' do
        @options = {:access_type => 'type'}
        subject.authorize_params['access_type'].should eq('type')
      end

      it 'should default to "offline"' do
        @options = {}
        subject.authorize_params['access_type'].should eq('offline')
      end
    end

    describe 'state' do
      it 'should set the state parameter' do
        @options = {:state => 'some_state'}
        subject.authorize_params['state'].should eq('some_state')
        subject.session['omniauth.state'].should eq('some_state')
      end

      it 'should set the omniauth.state dynamically' do
        subject.stub(:request) { double('Request', {:params => { 'state' => 'some_state' }, :env => {}}) }
        subject.authorize_params['state'].should eq('some_state')
        subject.session['omniauth.state'].should eq('some_state')
      end
    end

    describe 'hd' do
      it 'should set the hd (hosted domain) parameter if present' do
        @options = {:hd => 'example.com'}
        subject.authorize_params['hd'].should eq('example.com')
      end
    end

    describe 'login_hint' do
      it 'should set the login_hint parameter if present' do
        subject.stub(:request) { double('Request', {:params => { 'login_hint' => 'example@example.com' }, :env => {}}) }
        subject.authorize_params['login_hint'].should eq('example@example.com')
      end
    end
  end

  describe 'raw info' do
    it 'should include raw_info in extras hash by default' do
      subject.stub(:raw_info) { { :foo => 'bar' } }
      subject.extra[:raw_info].should eq({ :foo => 'bar' })
    end

    it 'should not include raw_info in extras hash when skip_info is specified' do
      @options = { :skip_info => true }
      subject.extra.should_not have_key(:raw_info)
    end
  end

  describe 'populate auth hash url' do
    it 'should populate url map in auth hash if link present in raw_info' do
      subject.stub(:raw_info) { { 'name' => 'Foo', 'link' => 'https://plus.google.com/123456' } }
      subject.info[:urls]['Google'].should eq('https://plus.google.com/123456')
    end

    it 'should not populate url map in auth hash if no link present in raw_info' do
      subject.stub(:raw_info) { { 'name' => 'Foo' } }
      subject.info.should_not have_key(:urls)
    end
  end

  describe 'image options' do
    it 'should return the image with size specified in the `image_size` option' do
      @options = { :image_size => 50 }
      subject.stub(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/url/photo.jpg' } }
      main_url, image_params = subject.info[:image].match(/^(.*)\/(.*)\/photo.jpg/).captures
      main_url.should eq('https://lh3.googleusercontent.com/url')
      image_params.should eq('s50')
    end

    it 'should return the image with width and height specified in the `image_size` option' do
      @options = { :image_size => { :width => 50, :height => 50 } }
      subject.stub(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/url/photo.jpg' } }
      main_url, image_params = subject.info[:image].match(/^(.*)\/(.*)\/photo.jpg/).captures
      image_params = image_params.split('-').inject({}) do |result, element|
        result[element.slice!(0)] = element
        result
      end
      main_url.should eq('https://lh3.googleusercontent.com/url')
      image_params['w'].should eq('50')
      image_params['h'].should eq('50')
    end

    it 'should return square image when `image_aspect_ratio` is specified' do
      @options = { :image_aspect_ratio => 'square' }
      subject.stub(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/url/photo.jpg' } }
      main_url, image_params = subject.info[:image].match(/^(.*)\/(.*)\/photo.jpg/).captures
      main_url.should eq('https://lh3.googleusercontent.com/url')
      image_params.should eq('c')
    end

    it 'should not break if no picture present in raw_info' do
      @options = { :image_aspect_ratio => 'square' }
      subject.stub(:raw_info) { { 'name' => 'User Without Pic' } }
      subject.info[:image].should be_nil
    end

    it 'should return original image if no options are provided' do
      subject.stub(:raw_info) { { 'picture' => 'https://lh3.googleusercontent.com/url/photo.jpg' } }
      subject.info[:image].should eq('https://lh3.googleusercontent.com/url/photo.jpg')
    end
  end

  describe 'build_access_token' do
    it 'should read access_token from hash' do
      @request.stub(:params).and_return('id_token' => 'valid_id_token', 'access_token' => 'valid_access_token')
      subject.should_receive(:verify_token).with('valid_id_token', 'valid_access_token').and_return true
      subject.should_receive(:client).and_return(:client)

      token = subject.build_access_token
      token.should be_instance_of(::OAuth2::AccessToken)
      token.token.should eq('valid_access_token')
      token.client.should eq(:client)
    end

    it 'should call super' do
      subject.should_receive(:build_access_token_without_access_token)
      subject.build_access_token
    end
  end

  describe 'verify_token' do
    before(:each) do
      subject.options.client_options[:connection_build] = proc do |builder|
        builder.request :url_encoded
        builder.adapter :test do |stub|
          stub.get('/oauth2/v2/tokeninfo?id_token=valid_id_token&access_token=valid_access_token') do |env|
            [200, {'Content-Type' => 'application/json; charset=UTF-8'}, MultiJson.encode(
              :issued_to => '000000000000.apps.googleusercontent.com',
              :audience => '000000000000.apps.googleusercontent.com',
              :user_id => '000000000000000000000',
              :scope => 'https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email',
              :expires_in => 3514,
              :email => 'me@example.com',
              :verified_email => true,
              :access_type => 'online'
            )]
          end
          stub.get('/oauth2/v2/tokeninfo?id_token=invalid_id_token&access_token=invalid_access_token') do |env|
            [400, {'Content-Type' => 'application/json; charset=UTF-8'}, MultiJson.encode(:error_description => 'Invalid Value')]
          end
        end
      end
    end

    it 'should verify token if access_token and id_token are valid and app_id equals' do
      subject.options.client_id =  '000000000000.apps.googleusercontent.com'
      subject.send(:verify_token, 'valid_id_token', 'valid_access_token').should == true
    end

    it 'should not verify token if access_token and id_token are valid but app_id is false' do
      subject.send(:verify_token, 'valid_id_token', 'valid_access_token').should == false
    end

    it 'should raise error if access_token or id_token is invalid' do
      expect {
        subject.send(:verify_token, 'invalid_id_token', 'invalid_access_token')
      }.to raise_error(OAuth2::Error)
    end
  end
end
