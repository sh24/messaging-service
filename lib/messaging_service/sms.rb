class SMS
  SMSResponse = Struct.new(:success, :service_provider, :reference_id)

  def self.send(opts = {})
    new(opts).send
  end

  def initialize(opts = {})
    @opts = opts
  end

  def send
    send_with_primary_service
  rescue => e
    return attempt_with_fallback_service if @opts[:with_fallback]
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
end
