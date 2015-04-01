require 'twilio-ruby'

module TwilioService
  def self.client
    Twilio::REST::Client.new(
      Settings.twilio.account_id,
      Settings.twilio.auth_token
    )
  end
end
