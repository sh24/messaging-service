module VoodooService
  def self.client
    VoodooSMS.new username: Settings.voodoo_sms.username, password: Settings.voodoo_sms.password
  end

  def self.clients
    Settings.sms_providers.voodoo.map do |credentials|
      voodoo_sms_client username: username, password: password
    end
  end

  private

  def voodoo_sms_client(username:, password:)
    VoodooSMS.new username, password
  end
end
