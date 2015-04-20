module VoodooService
  def self.client
    VoodooSMS.new(
      Settings.voodoo_sms.username,
      Settings.voodoo_sms.password
    )
  end
end
