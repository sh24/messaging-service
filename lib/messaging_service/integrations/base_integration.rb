# frozen_string_literal: true

module MessagingService
  module Integrations
    class BaseIntegration

      RESPONSE_TIMEOUT_SECONDS = 15

      attr_reader :username, :password, :prefixed_service_numbers, :destination_number, :notifier

      def initialize(username, password, prefixed_service_numbers, destination_number, notifier)
        @username = username
        @password = password
        @prefixed_service_numbers = prefixed_service_numbers
        @destination_number = destination_number
        @notifier = notifier
      end

      def send_message(message)
        Timeout.timeout(RESPONSE_TIMEOUT_SECONDS) do
          build_response execute_message_send(message)
        end
      rescue StandardError => e
        handle_send_exception(error: e)
      end

      def handle_send_exception(error:)
        raise SMS::BlocklistedNumberError if blocklist_error?(error)

        notify(error)
        failure_response
      end

      protected

      def execute_message_send(_message)
        raise 'OVERRIDE ME!'
      end

      def build_response(_response)
        raise 'OVERRIDE ME!'
      end

      def success_response(reference_id:)
        SMS::Response.new(true, self.class.service_name, reference_id, chosen_service_number)
      end

      def failure_response
        SMS::Response.new(false, self.class.service_name, nil, chosen_service_number)
      end

      def chosen_service_number
        @chosen_service_number ||= prefixed_service_numbers.find do |prefix, _service_number|
          destination_number[/^\+?#{prefix}/]
        end&.last || fallback_service_number
      end

      def notify(error)
        notifier&.notify(error)
      end

      def fallback_service_number
        prefixed_service_numbers.values.first
      end

      def blocklist_error?(error)
        VoodooIntegration.blocklist_error?(error) || TwilioIntegration.blocklist_error?(error)
      end

    end
  end
end
