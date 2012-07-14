
# this has to be first for coverage tool to work right
if ENV.has_key?('USE_SIMPLECOV')
  require 'simplecov'
  SimpleCov.add_filter '/plugins/'
  SimpleCov.add_group 'Indexers', 'app/indexers'
  SimpleCov.start 'rails'
  SimpleCov.groups.delete 'Plugins'
  SimpleCov.groups.delete 'Mailers'
  SimpleCov.groups.delete 'Controllers'
end

# why in the heck can't I seem to get bundler to do this??
require "text"
require "unicode_utils"
require "valium"
require "each_batched"
require "activerecord-import"

# set up the dummy rails app
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rspec/rails"

# factory_girl missed some factories, and only looked inside the dummy app :P
Dir[File.expand_path("../factories/**/*.rb",  __FILE__)].each { |f| load f }

# load any support files
Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |f| require f }

# configure rspec environment
RSpec.configure do |config|
  config.mock_with :rspec
  config.use_transactional_fixtures = true
  config.include FactoryGirl::Syntax::Methods
end
