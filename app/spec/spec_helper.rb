require 'rack/test'
require 'webmock/rspec'
RSpec.configure do |config|
  config.include Rack::Test::Methods
end
