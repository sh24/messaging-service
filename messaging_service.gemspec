Gem::Specification.new do |s|
  s.name        = 'messaging_service'
  s.version     = '0.1.2'
  s.date        = '2014-04-01'
  s.summary     = 'Messaging service'
  s.description = 'Shared SMS messaging service'
  s.authors     = ['Tom Sabin']
  s.email       = 'tom.sabin@unboxedconsulting.com'
  s.files       = ['lib/messaging_service']
  s.homepage    = 'https://github.com/sh24'
  s.license     = 'MIT'

  s.add_runtime_dependency 'voodoo_sms', ['~> 1.1.1']
  s.add_runtime_dependency 'twilio-ruby', ['~> 3.14.0']
  s.add_runtime_dependency 'airbrake', ['~> 4.0.0']

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'vcr'
end
