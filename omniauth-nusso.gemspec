# frozen_string_literal: true

require_relative 'lib/omniauth/nusso/version'

Gem::Specification.new do |spec|
  spec.name          = 'omniauth-nusso'
  spec.version       = OmniAuth::Nusso::VERSION
  spec.license       = 'Apache-2.0'
  spec.authors       = ['Brendan Quinn']
  spec.email         = ['brendan-quinn@northwestern.edu']

  spec.summary       = 'OmniAuth strategy for Northwestern University Agentless SSO.'
  spec.homepage      = 'https://github.com/nulib/omniauth-nusso'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/nulib/omniauth-nusso'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'omniauth'
  spec.add_runtime_dependency 'faraday'

  spec.add_development_dependency 'bixby', '~> 2.0'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'coveralls', '~> 0.8.3'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'webmock'
end
