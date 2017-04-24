# frozen_string_literal: true

require 'bundler/setup'
Bundler.setup

require 'messaging_service'
require 'webmock/rspec'
require 'vcr'

class Settings

  def self.voodoo_sms
    Struct.new(:username, :password).new('username', 'password')
  end

  def self.twilio
    Struct.new(:account_id, :auth_token, :sms_number).new('account_id', 'auth_token', '440000000000')
  end

end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.default_cassette_options = {
    match_requests_on: [:method, VCR.request_matchers.uri_without_param(:msg, :dest)],
  }
end
