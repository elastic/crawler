# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'faux/version'

Gem::Specification.new do |spec|
  spec.name          = "faux"
  spec.version       = Faux::VERSION
  spec.authors       = ["Elastic Enterprise Search Team"]
  spec.email         = ["enterprise-search@elastic.co"]
  spec.description   = "Artisan faux web pages, by Wes Andreson"
  spec.summary       = "Faux is little Rack-based DSL for generating websites"
  spec.homepage      = "https://swiftype.com"
  spec.license       = "MIT"

  spec.files         = Dir.glob("{lib,sites}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  if spec.respond_to?(:metadata)
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'geminabox'

  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'nokogiri'
  spec.add_runtime_dependency 'rack'
  spec.add_runtime_dependency 'rack-mount'
end
