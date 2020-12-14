# frozen_string_literal: true

require 'timeout'
require 'active_support'
require 'active_support/core_ext'

module MessagingService
  class SMS

    class VoodooOverridenError < StandardError; end
    class BlocklistedNumberError < StandardError; end

    Response             = Struct.new(:success, :service_provider, :reference_id, :service_number)
    OVERRIDE_VOODOO_FILE = 'tmp/OVERRIDE_VOODOO'

    def initialize(primary_provider:, voodoo_credentials: nil, twilio_credentials: nil, fallback_provider: nil, notifier: nil)
      raise_argument_error if no_credentials_provided?(voodoo_credentials, twilio_credentials)

      @voodoo_credentials = voodoo_credentials
      @twilio_credentials = twilio_credentials
      choose_integrations(primary_provider, fallback_provider)
      @notifier = notifier
    end

    def send(to:, message:)
      if_sending_fails_unexpectedly(send_with_primary_provider(to: to, message: message)) do
        send_with_fallback_provider(to: to, message: message)
      end
    end

    private

    def if_sending_fails_unexpectedly(primary_response)
      return primary_response if primary_response.success

      fallback_response = yield
      fallback_response&.success ? fallback_response : primary_response
    end

    def send_with_primary_provider(to:, message:)
      build_integration(@primary_integration, @primary_credentials, to).send_message(message)
    end

    def send_with_fallback_provider(to:, message:)
      return unless @fallback_integration && @fallback_credentials

      build_integration(@fallback_integration, @fallback_credentials, to).send_message(message)
    end

    def raise_argument_error
      raise ArgumentError, 'Provide at least one set of credentials'
    end

    def no_credentials_provided?(*credentials)
      credentials.all?(&:nil?)
    end

    def choose_integrations(primary_provider, fallback_provider)
      @primary_integration, @primary_credentials = provider_to_integration(primary_provider)
      @fallback_integration, @fallback_credentials = provider_to_integration(fallback_provider)
    end

    def provider_to_integration(provider)
      case provider.presence
      when nil
        [nil, nil]
      when :voodoo
        [Integrations::VoodooIntegration, @voodoo_credentials]
      when :twilio
        [Integrations::TwilioIntegration, @twilio_credentials]
      else
        raise "Unknown SMS service integration: #{provider}"
      end
    end

    def build_integration(integration_klass, credentials, destination_number)
      integration_klass.new(
        credentials[:username],
        credentials[:password],
        credentials[:numbers],
        destination_number,
        @notifier
      )
    end

  end
end
