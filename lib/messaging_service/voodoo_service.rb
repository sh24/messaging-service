module VoodooService
  def self.client
    self.voodoo_client username: Settings.voodoo_sms.username, password: Settings.voodoo_sms.password
  end

  def self.clients
    Settings.sms_providers.voodoo.map do |credentials|
      self.voodoo_client username: credentials.username, password: credentials.password
    end
  end

  def self.voodoo_client(username:, password:)
    VoodooSMS.new username, password
  end
end
