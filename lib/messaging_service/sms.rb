# frozen_string_literal: true

require 'timeout'
require 'active_support'
require 'active_support/core_ext'

module MessagingService
  class SMS

    class BlocklistedNumberError < StandardError; end

    Response = Struct.new(:success, :service_provider, :reference_id, :service_number)

    def initialize(primary_provider:,
                   credentials: nil,
                   voodoo_credentials: nil,
                   twilio_credentials: nil,
                   fallback_provider: nil,
                   notifier: nil,
                   metrics_recorder: NullMetricsRecorder.new)
      raise_argument_error if no_credentials_provided?(voodoo_credentials, twilio_credentials)

      # Allows old interface
      if credentials.nil?
        if primary_provider == :voodoo
         credentials = [voodoo_credentials, twilio_credentials].compact
        else
          credentials = [twilio_credentials, voodoo_credentials].compact
        end
      end

      add_integration_class(credentials)
      @notifier = notifier
      @metrics_recorder = metrics_recorder
    end

    def send(to:, message:)
      @credentials.each do |credential|
        response = build_integration(credential, to).send_message(message)
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

    def add_integration_class(credentials)
      @credentials = credentials.map do |credential|
        credential[:integration_klass] = provider_to_integration(credential[:provider])
      end
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

    def build_integration(credential, destination_number)
      credential[:integration_klass].new(
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
