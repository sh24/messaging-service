# frozen_string_literal: true

require 'timeout'
require 'active_support'
require 'active_support/core_ext'

module MessagingService
  class SMS

    class BlocklistedNumberError < StandardError; end

    Response = Struct.new(:success, :service_provider, :reference_id, :service_number)

    def initialize(primary_provider: nil,
                   credentials: nil,
                   voodoo_credentials: nil,
                   twilio_credentials: nil,
                   notifier: nil,
                   metrics_recorder: NullMetricsRecorder.new)
      raise_argument_error if no_credentials_provided?(voodoo_credentials, twilio_credentials)

      # We can now pass a mixed list of voodoo and twilio credentials as an array of credentials to init.
      # We attempt to send a sms using each of the creds in turn, until the message is sent successfully.
      # The following allows the old interface (passing both twilio and voodoo creds, with a primary provider flag) to continue to work
      @credentials = if credentials.nil?
                       if primary_provider == :voodoo
                         [voodoo_credentials, twilio_credentials].compact
                       else
                         [twilio_credentials, voodoo_credentials].compact
                       end
                     else
                       credentials
                     end

      @notifier = notifier
      @metrics_recorder = metrics_recorder
    end

    def send(to:, message:)
      @credentials.each do |credential|
        integration_klass = provider_to_integration_klass(credential[:provider])
        response = build_integration(credential, integration_klass, to).send_message(message)
        break response if response.success
      end

      response
    end

    private

    def raise_argument_error
      raise ArgumentError, 'Provide at least one set of credentials'
    end

    def no_credentials_provided?(*credentials)
      credentials.all?(&:nil?)
    end

    def provider_to_integration_klass(provider)
      case provider.presence
      when nil
        nil
      when :voodoo
        Integrations::VoodooIntegration
      when :twilio
        Integrations::TwilioIntegration
      else
        raise "Unknown SMS service integration: #{provider}"
      end
    end

    def build_integration(integration_klass, credential, destination_number)
      integration_klass.new(
        credential[:username],
        credential[:password],
        credential[:numbers],
        destination_number,
        @notifier,
        metrics_recorder: @metrics_recorder
      )
    end

  end
end
