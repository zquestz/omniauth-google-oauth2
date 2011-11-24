# NOTE it would be useful if this lived in omniauth-oauth2 eventually
shared_examples 'an oauth2 strategy' do
  describe '#client' do
    it 'should be initialized with symbolized client_options' do
      @options = { :client_options => { 'authorize_url' => 'https://example.com' } }
      subject.client.options[:authorize_url].should == 'https://example.com'
    end
  end

  describe '#authorize_params' do
    it 'should include any authorize params passed in the :authorize_params option' do
      @options = { :authorize_params => { :foo => 'bar', :baz => 'zip' } }
      subject.authorize_params['foo'].should eq('bar')
      subject.authorize_params['baz'].should eq('zip')
    end

    it 'should include top-level options that are marked as :authorize_options' do
      @options = { :authorize_options => [:scope, :foo], :scope => 'http://bar', :foo => 'baz' }
      subject.authorize_params['scope'].should eq('http://bar')
      subject.authorize_params['foo'].should eq('baz')
    end
  end

  describe '#token_params' do
    it 'should include any token params passed in the :token_params option' do
      @options = { :token_params => { :foo => 'bar', :baz => 'zip' } }
      subject.token_params['foo'].should eq('bar')
      subject.token_params['baz'].should eq('zip')
    end

    it 'should include top-level options that are marked as :token_options' do
      @options = { :token_options => [:scope, :foo], :scope => 'bar', :foo => 'baz' }
      subject.token_params['scope'].should eq('bar')
      subject.token_params['foo'].should eq('baz')
    end
  end
end