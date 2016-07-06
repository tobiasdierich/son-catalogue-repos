# spec/spec_helper.rb
require 'rack/test'
require 'rspec'
require 'webmock/rspec'

ENV['RACK_ENV'] ||= 'test'

WebMock.allow_net_connect!

$LOAD_PATH << File.expand_path('../..', __FILE__)
require './main'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.mock_with :rspec
  config.include WebMock::API
end
