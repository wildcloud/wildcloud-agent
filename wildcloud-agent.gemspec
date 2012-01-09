lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'wildcloud/agent/version'

Gem::Specification.new do |s|
  s.name        = 'wildcloud-agent'
  s.version     = Wildcloud::Agent::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Marek Jelen']
  s.email       = ['marek@jelen.biz']
  s.homepage    = 'http://github.com/wildcloud'
  s.summary     = 'Monitoring & management'
  s.description = 'Manages processes for the platform and provides monitoring'
  s.license     = 'Apache2'

  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency 'amqp', '0.8.4'
  s.add_dependency 'sigar', '0.7.0'
  s.add_dependency 'json', '1.6.4'
  s.add_dependency 'wildcloud-logger', '0.0.2'
  s.add_dependency 'wildcloud-configuration', '0.0.1'

  s.files        = Dir.glob('{bin,lib,public}/**/*') + %w(LICENSE README.md CHANGELOG.md)
  s.executables = %w(wildcloud-agent)
  s.require_path = 'lib'
end