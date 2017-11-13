# frozen_string_literal: true

require 'timeout'

module MessagingService
  class SMS

    SMSResponse          = Struct.new(:success, :service_provider, :reference_id)
    OVERRIDE_VOODOO_FILE = 'tmp/OVERRIDE_VOODOO'

    def initialize(voodoo_credentials: nil, twilio_credentials: nil, primary_provider:, fallback_provider: nil, notifier: nil)
      raise_argument_error if no_credentials_provided?(voodoo_credentials, twilio_credentials)

      @voodoo_credentials = voodoo_credentials
      @twilio_credentials = twilio_credentials
      @primary_provider   = primary_provider
      @fallback_provider  = fallback_provider
      @notifier           = notifier
    end

    def send(to:, message:, timeout: 15)
      send_with_primary_provider to: to, message: message, timeout: timeout
    rescue StandardError => e
      return send_with_fallback_provider(to: to, message: message, timeout: timeout) if fallback_provider_provided?

      notify(e)
      SMSResponse.new(false)
    end

    private def send_with_primary_provider(**arguments)
      return send_with_twilio(arguments) if twilio_primary_provider?
      return send_with_voodoo(arguments) if voodoo_primary_provider?
    end

    private def send_with_fallback_provider(**arguments)
      return send_with_voodoo(arguments) if voodoo_fallback_provider?
      return send_with_twilio(arguments) if twilio_fallback_provider?
    rescue StandardError => e
      notify(e)
      SMSResponse.new(false)
    end

    private def send_with_voodoo(to:, message:, timeout: 15)
      Timeout.timeout(timeout) do
        reference_id = voodoo_service.send_sms(@voodoo_credentials[:number], to, message)
        SMSResponse.new(true, 'voodoo', reference_id)
      end
    end

    private def send_with_twilio(to:, message:, **_)
      message = twilio_service.account.messages.create from: @twilio_credentials[:number], to: to, body: message
      reference_id = message.sid if message
      SMSResponse.new true, 'twilio', reference_id
    end

    private def fallback_provider_provided?
      !@fallback_provider.nil?
    end

    private def voodoo_overriden?
      File.exist?(OVERRIDE_VOODOO_FILE) && twilio_credentials_provided?
    end

    private def twilio_service
      Twilio::REST::Client.new @twilio_credentials[:username], @twilio_credentials[:password]
    end

    private def voodoo_service
      VoodooSMS.new @voodoo_credentials[:username], @voodoo_credentials[:password]
    end

    private def notify error
      @notifier&.notify(error)
    end

    private def twilio_credentials_provided?
      !@twilio_credentials.nil?
    end

    private def voodoo_primary_provider?
      @primary_provider == :voodoo
    end

    private def twilio_primary_provider?
      @primary_provider == :twilio || voodoo_overriden?
    end

    private def voodoo_fallback_provider?
      @fallback_provider == :voodoo || voodoo_overriden?
    end

    private def twilio_fallback_provider?
      @fallback_provider == :twilio
    end

    private def raise_argument_error
      raise ArgumentError, 'Provide at least one set of credentials'
    end

    private def no_credentials_provided?(*credentials)
      credentials.all?(&:nil?)
    end

  end
end
