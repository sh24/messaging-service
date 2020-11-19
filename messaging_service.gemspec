# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'messaging_service/version'

Gem::Specification.new do |s|
  s.name        = 'messaging_service'
  s.version     = MessagingService::VERSION
  s.date        = '2017-04-20'
  s.summary     = 'Messaging Service'
  s.description = 'Shared SMS messaging services'
  s.authors     = ['Tom Sabin', 'SH:24']
  s.email       = 'devops@sh24.org.uk'
  s.files       = ['lib/messaging_service']
  s.homepage    = 'https://github.com/sh24'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 2.5.0'

  s.add_runtime_dependency 'activesupport', ['> 5.0.0']
  s.add_runtime_dependency 'airbrake', ['> 4.0.0']
  s.add_runtime_dependency 'twilio-ruby', ['~> 5.0']
  s.add_runtime_dependency 'voodoo_sms', ['> 1.1']

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency 'rake', '> 10.0'
  s.add_development_dependency 'rake-n-bake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-performance'
  s.add_development_dependency 'semver2'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
end
