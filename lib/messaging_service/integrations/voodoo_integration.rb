# frozen_string_literal: true

module MessagingService
  module Integrations
    class VoodooIntegration < BaseIntegration

      OVERRIDE_VOODOO_FILE = 'tmp/OVERRIDE_VOODOO'

      def self.service_name
        'voodoo'
      end

      def self.blocklist_error?(error)
        error.is_a?(VoodooSMS::Error::BadRequest) && error.message =~ /Black List Number Found/i
      end

      private

      def execute_message_send(message)
        raise SMS::VoodooOverriddenError if voodoo_overridden?

        service.send_sms(chosen_service_number, @destination_number, message)
      end

      def build_response(response)
        reference_id = json_parse_reference_id(response)
        success_response(reference_id: reference_id)
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
        File.exist?(OVERRIDE_VOODOO_FILE)
      end

    end
  end
end
