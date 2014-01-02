# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'geomodel/version'

Gem::Specification.new do |spec|
  spec.name          = 'geomodel'
  spec.version       = Geomodel::VERSION
  spec.authors       = ['Brian Sam-Bodden']
  spec.email         = ['bsbodden@integrallis.com']
  spec.description   = %q{A Ruby implementation of the Geomodel concept}
  spec.summary       = %q{Geomodel aims to provide a generalized solution for performing basic indexing 
  and querying of geospatial data in non-relation environments. At the core, this 
  solution utilizes geohash-like objects called geocells.}
  spec.homepage      = 'https://github.com/integrallis/geomodel'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  
  spec.add_dependency 'geocoder', '~> 1.1.9'
  spec.add_dependency 'hashie', '~> 2.0.5'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'hashie'
  spec.add_development_dependency 'debugger'
  spec.add_development_dependency 'launchy'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'coveralls'
end
