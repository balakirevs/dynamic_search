require 'bundler/setup'
Bundler.setup
require 'pry'
require 'simplecov'

SimpleCov.start
require 'dynamic_search' # and any other gems you need

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
end
