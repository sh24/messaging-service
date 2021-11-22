# frozen_string_literal: true

module MessagingService
  module Integrations
    class VoodooIntegration < BaseIntegration

      class IntegrationDisabledError < StandardError; end

      KILL_SWITCH_ENV_VAR = 'VOODOO_DISABLE_MESSAGING'

      def self.service_name
        'voodoo'
      end

      private

      def execute_message_send(message)
        raise IntegrationDisabledError if voodoo_overridden?

        service.send_sms(chosen_service_number, @destination_number, message)
      end

      def build_response(response)
        reference_id = json_parse_reference_id(response)
        success_response(reference_id: reference_id)
      end

      def blocklist_error?(error)
        error.is_a?(VoodooSMS::Error::BadRequest) && error.message =~ /Black List Number Found/i
      end

      def service
        VoodooSMS.new @username, @password
      end

      def json_parse_reference_id(reference_id)
        JSON.parse(reference_id.to_s).first
      rescue JSON::ParserError
        reference_id
      end

      def voodoo_overridden?
        ENV[KILL_SWITCH_ENV_VAR].present?
      end

    end
  end
end
