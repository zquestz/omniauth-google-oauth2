# frozen_string_literal: true

require File.join('bundler', 'setup')
require 'rspec'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # Without this, a stub or expectation naming a method the object does not
    # have is silently accepted, so a renamed method leaves a spec that cannot
    # fail behind it.
    mocks.verify_partial_doubles = true
  end
end
