$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "indexed_search/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "indexed_search"
  s.version     = IndexedSearch::VERSION
  s.authors     = ["David Burry"]
  s.homepage    = "TODO"
  s.summary     = "A rich indexed search engine for Rails written in pure Ruby."
  s.description = "A rich indexed search engine for Rails written in pure Ruby."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 3.2.2"
  s.add_dependency "text"
  s.add_dependency "unicode_utils"
  s.add_dependency "valium"
  s.add_dependency "each_batched"

  s.add_development_dependency "mysql2"
  s.add_development_dependency "simplecov-html"
  s.add_development_dependency "rspec"
end
