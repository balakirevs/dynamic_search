# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "dynamic_search/version"

Gem::Specification.new do |s|
  s.name        = "dynamic_search"
  s.version     = DynamicSearch::Version::VERSION
  s.authors     = ["Aleksandr Balakiriev"]
  s.email       = ["balakirevs@i.ua"]
  s.homepage    = ""
  s.summary     = %q{Dynamic search for rails}
  s.description = %q{Helpers and angular module to make fancy dynamic searches with arel.}

  s.files       = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  s.bindir       = "exe"
  s.executables  = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('sass-rails', '>= 6.0')
  s.add_dependency('coffee-rails', '>= 5.0')
  s.add_dependency('i18n-js', '>= 3.0.11')

  s.add_development_dependency "rspec_junit_formatter"
  s.add_development_dependency "rspec", "~> 2.14.0"
  s.add_development_dependency "rails", ">= 4.0"
  s.add_development_dependency "pry", "~> 0.9"
  s.add_development_dependency "simplecov", "~> 0.8"
end

