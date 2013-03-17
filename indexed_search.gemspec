$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "indexed_search/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "indexed_search"
  s.version     = IndexedSearch::VERSION
  s.authors     = ["David Burry"]
  s.homepage    = "https://github.com/dburry/indexed_search"
  s.summary     = "A rich indexed search engine for Rails written in pure Ruby."
  s.description = "A rich indexed search engine for Rails written in pure Ruby."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 3.0"
  s.add_dependency "text"
  s.add_dependency "unicode_utils"
  s.add_dependency "valium"
  s.add_dependency "each_batched", ">= 0.1.3"
  s.add_dependency "activerecord-import"

  s.add_development_dependency "mysql2"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "simplecov-html"
  s.add_development_dependency "database_cleaner"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "launchy"
  s.add_development_dependency "composite_primary_keys"
end
