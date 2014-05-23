# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spree/adyen/version'

Gem::Specification.new do |spec|
  spec.name          = "spree-adyen"
  spec.version       = Spree::Adyen::VERSION
  spec.authors       = ["Washington Luiz"]
  spec.email         = ["huoxito@gmail.com"]
  spec.description   = "Plugs Adyen Payment Gateway into Spree Stores"
  spec.summary       = "Plugs Adyen Payment Gateway into Spree Stores"
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "factory_girl"
  spec.add_development_dependency 'pg'
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency 'sass-rails', '~> 4.0.2'
  spec.add_development_dependency 'sqlite3'

  spec.add_runtime_dependency "adyen", "~> 1.4.0"
  spec.add_runtime_dependency "spree_core", ">= 2.2.0"
end
