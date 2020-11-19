# frozen_string_literal: true

module MessagingService
  module Integrations
    class TwilioIntegration < BaseIntegration

      def self.service_name
        'twilio'
      end

      def self.blocklist_error?(error)
        # https://www.twilio.com/docs/errors/21610
        error.is_a?(Twilio::REST::RestError) && error.code == 21_610
      end

      private

      def execute_message_send(message)
        to = @destination_number[0] == '+' ? @destination_number : "+#{@destination_number}"

        service.api.account.messages.create from: chosen_service_number, to: to, body: message
      end

      def build_response(response)
        success_response(reference_id: response&.sid)
      end

      def service
        Twilio::REST::Client.new @username, @password
      end

    end
  end
end
