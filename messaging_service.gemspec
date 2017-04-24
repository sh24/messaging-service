Gem::Specification.new do |s|
  s.name        = 'messaging_service'
  s.version     = '1.0.0'
  s.date        = '2017-04-20'
  s.summary     = 'Messaging Service'
  s.description = 'Shared SMS messaging services'
  s.authors     = ['Tom Sabin']
  s.email       = 'tom.sabin@unboxedconsulting.com'
  s.files       = ['lib/messaging_service']
  s.homepage    = 'https://github.com/sh24'
  s.license     = 'MIT'

  s.add_runtime_dependency 'voodoo_sms', ['~> 1.1.1']
  s.add_runtime_dependency 'twilio-ruby', ['~> 3.14.0']
  s.add_runtime_dependency 'airbrake', ['> 4.0.0']

  s.add_development_dependency 'bundler', '~> 1.12'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'rake', '> 10.0'
  s.add_development_dependency 'rake-n-bake'
  s.add_development_dependency 'semver2'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'
end
