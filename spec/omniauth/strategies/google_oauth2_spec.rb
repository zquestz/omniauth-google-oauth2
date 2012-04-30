require 'spec_helper'
require 'omniauth-google-oauth2'

describe OmniAuth::Strategies::GoogleOauth2 do
  subject do
    OmniAuth::Strategies::GoogleOauth2.new(nil, @options || {})
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
    it "has the correct callback path" do
      subject.callback_path.should eq('/auth/google_oauth2/callback')
    end
  end

  describe '#authorize_params' do
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

    it 'should set default scope to userinfo.email,userinfo.profile' do
      @options = { :authorize_options => [:scope]}
      subject.authorize_params['scope'].should eq('https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile')
    end

    it 'should set the state parameter' do
      @options = {:state => "some_state"}
      subject.authorize_params['state'].should eq('some_state')
    end

    it 'should allow request parameter to override approval_prompt' do
      @options = {:approval_prompt => ''} # non-nil prevent default 'force'
      # stub the request
      subject.stub!(:request).and_return( Rack::Request.new( {'QUERY_STRING' => "approval_prompt=force", "rack.input" => ""}))
      subject.authorize_params['approval_prompt'].should eq('force')
    end

    it 'should include raw_info in extras hash by default' do
      subject.stub(:raw_info) { { :foo => 'bar' } }
      subject.extra[:raw_info].should eq({ :foo => 'bar' })
    end

    it 'should not include raw_info in extras hash when skip_info is specified' do
      @options = { :skip_info => true }
      subject.extra.should_not have_key(:raw_info)
    end
  end

end