# frozen_string_literal: true

module MessagingService
  module VoodooService
    def self.client(username: Settings.voodoo_sms.username, password: Settings.voodoo_sms.password)
      VoodooSMS.new username, password
    end
  end
end
