
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

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with :truncation
  end
  config.before(:each) do
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
  end
end
