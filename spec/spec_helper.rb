require File.join('bundler', 'setup')
require 'rspec'

Dir[File.expand_path(File.join('..', 'support', '**', '*'), __FILE__)].each do |f|
  require f
end

RSpec.configure do |config|
end