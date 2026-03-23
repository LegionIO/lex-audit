# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'legion/extensions/audit/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-audit'
  spec.version       = Legion::Extensions::Audit::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'Legion::Extensions::Audit'
  spec.description   = 'Immutable audit logging with SHA-256 hash chain for LegionIO execution decisions'
  spec.homepage      = 'https://github.com/LegionIO/lex-audit'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-audit'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-audit/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-audit'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-audit/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'legion-cache', '>= 1.3.11'
  spec.add_dependency 'legion-crypt', '>= 1.4.9'
  spec.add_dependency 'legion-data', '>= 1.4.17'
  spec.add_dependency 'legion-json', '>= 1.2.1'
  spec.add_dependency 'legion-logging', '>= 1.3.2'
  spec.add_dependency 'legion-settings', '>= 1.3.14'
  spec.add_dependency 'legion-transport', '>= 1.3.9'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'sequel'
  spec.add_development_dependency 'sqlite3'
end
