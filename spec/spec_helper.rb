if ENV.has_key?('USE_SIMPLECOV')
  require 'simplecov'
  SimpleCov.add_filter '/plugins/'
  SimpleCov.add_group 'Indexers', 'app/indexers'
  SimpleCov.start 'rails'
  SimpleCov.groups.delete 'Plugins'
  SimpleCov.groups.delete 'Mailers'
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rspec/rails'
require File.expand_path("../factories", __FILE__)

require 'database_cleaner'

Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  config.mock_with :rspec
  config.use_transactional_fixtures = true
end
