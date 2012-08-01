# -*- encoding: utf-8 -*-
require File.expand_path('../lib/query_generator/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Stefan Exner"]
  gem.email         = ["ste@informatik.uni-kiel.de"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = "http://www.github.com/Stex/query_generator"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "query_generator"
  gem.require_paths = ["lib"]
  gem.version       = QueryGenerator::VERSION

  gem.add_dependency("haml")
  gem.add_dependency("sass")
  gem.add_dependency("will_paginate")
end
