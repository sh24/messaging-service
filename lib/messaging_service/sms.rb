# frozen_string_literal: true

require 'timeout'

module MessagingService
  class SMS

    SMSResponse          = Struct.new(:success, :service_provider, :reference_id)
    OVERRIDE_VOODOO_FILE = 'tmp/OVERRIDE_VOODOO'.freeze

    def initialize(voodoo_credentials:, twilio_credentials: nil, notifier: nil)
      @voodoo_credentials = voodoo_credentials
      @twilio_credentials = twilio_credentials
      @notifier           = notifier
    end

    def send(to:, message:, timeout: 15)
      if fallback_allowed? && voodoo_overriden?
        response = send_with_twilio(to: to, message: message)
        return response if response.success
      end
      Timeout.timeout(timeout){ send_with_voodoo(to: to, message: message) }
    rescue => e
      return send_with_twilio(to: to, message: message) if fallback_allowed?
      notify(e)
      SMSResponse.new(false)
    end

    private def send_with_voodoo(to:, message:)
      reference_id = voodoo_service.send_sms(@voodoo_credentials.number, to, message)
      SMSResponse.new(true, 'voodoo', reference_id)
    end

    private def send_with_twilio(to:, message:)
      twilio_service.account.messages.create(from: @twilio_credentials.number, to: to, body: message)
      SMSResponse.new(true, 'twilio')
    rescue => e
      notify(e)
      SMSResponse.new(false)
    end

    private def fallback_allowed?
      !@twilio_credentials.nil?
    end

    private def voodoo_overriden?
      File.exist?(OVERRIDE_VOODOO_FILE)
    end

    private def twilio_service
      Twilio::REST::Client.new @twilio_credentials.username, @twilio_credentials.password
    end

    private def voodoo_service
      VoodooSMS.new @voodoo_credentials.username, @voodoo_credentials.password
    end

    private def notify error
      @notifier&.notify(error)
    end

  end
end
