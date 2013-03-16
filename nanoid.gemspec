# -*- encoding: utf-8 -*-
$:.unshift File.expand_path("../lib", __FILE__)
$:.unshift File.expand_path("../../lib", __FILE__)

require 'nanoid/version'

Gem::Specification.new do |gem|
  gem.authors       = ["Kareem Kouddous"]
  gem.email         = ["kareemknyc@gmail.com"]
  gem.description   = "Rubymotion ORM for Nanostore"
  gem.summary       = "Rubymotion ORM for Nanostore"
  gem.homepage      = "https://github.com/kareemk/nanoid"

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "nanoid"
  gem.require_paths = ["lib"]
  gem.version       = Nanoid::VERSION

  gem.add_dependency "activemodel", "~> 3.2.9"
  gem.add_dependency 'motion-cocoapods', '>= 1.2.1'
  gem.add_development_dependency 'motion-redgreen'
end
