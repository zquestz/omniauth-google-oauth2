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

  describe 'redirect_uri' do
    before do
      subject.stub(:callback_url).and_return('http://example.host/default')
    end

    it 'should be callback_url by default' do
      subject.request_phase
      subject.options[:authorize_params][:redirect_uri].should eql('http://example.host/default')
    end
    
    it 'should be overriden by an option' do
      subject.options[:redirect_uri] = 'http://example.host/override'
      subject.request_phase
      subject.options[:authorize_params][:redirect_uri].should eql('http://example.host/override')
    end
  end

  describe '#callback_path' do
    it "has the correct callback path" do
      subject.callback_path.should eq('/auth/google_oauth2/callback')
    end
  end

  # These are setup during the request_phase
  # At init they are blank
  describe '#authorize_params' do
    it "has no authorize params at init" do
      subject.authorize_params.should be_empty
    end
  end
end