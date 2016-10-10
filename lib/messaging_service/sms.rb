require 'timeout'

class SMS
  SMSResponse = Struct.new(:success, :service_provider, :reference_id)
  OVERRIDE_VOODOO_FILE = 'tmp/OVERRIDE_VOODOO'

  def self.send(opts = {})
    new(opts).send
  end

  def initialize(opts = {})
    @opts = opts
  end

  def send(timeout_time = 15)
    if fallback_allowed? && voodoo_overriden?
      response = attempt_with_fallback_service
      return if response.success
    end
    Timeout::timeout(timeout_time) { send_with_primary_service }
  rescue => e
    return attempt_with_fallback_service if fallback_allowed?
    Airbrake.notify(e)
    SMSResponse.new(false)
  end

  private

  def send_with_primary_service
    reference_id = VoodooService.client.send_sms(Settings.voodoo_sms.sender_id, @opts[:to], @opts[:msg])
    SMSResponse.new(true, 'voodoo', reference_id)
  end

  def attempt_with_fallback_service
    TwilioService.client.account.messages.create({
      from: Settings.twilio.sms_number, to: @opts[:to], body: @opts[:msg]
    })
    SMSResponse.new(true, 'twilio')
  rescue => e
    Airbrake.notify(e)
    SMSResponse.new(false)
  end

  private def fallback_allowed?
    @opts[:with_fallback]
  end

  private def voodoo_overriden?
    File.exist?(OVERRIDE_VOODOO_FILE)
  end
end
