lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'catalogx_client/version'

Gem::Specification.new do |gem|
  gem.name          = "catalogx_client"
  gem.version       = CatalogXClient::VERSION
  gem.authors       = ["Dan McGuire"]
  gem.email         = ["dan.mcguire@blueshift.com"]
  gem.description   = %q{Ruby wrapper for the CatalogX API}
  gem.summary       = %q{Ruby wrapper for the CatalogX API}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "faraday"
  gem.add_runtime_dependency "faraday_middleware"
end
