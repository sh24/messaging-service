# frozen_string_literal: true

module MessagingService
  module Integrations
    class BaseIntegration

      RESPONSE_TIMEOUT_SECONDS = 15

      attr_reader :username, :password, :prefixed_service_numbers, :destination_number, :notifier, :metrics_recorder, :account_sid

      def initialize(username, password, prefixed_service_numbers, destination_number, notifier, account_sid, metrics_recorder:) # rubocop:disable Metrics/ParameterLists
        @username = username
        @password = password
        @account_sid = account_sid
        @prefixed_service_numbers = prefixed_service_numbers
        @destination_number = destination_number
        @notifier = notifier
        @metrics_recorder = metrics_recorder
      end

      def send_message(message)
        response = Timeout.timeout(RESPONSE_TIMEOUT_SECONDS) do
          raw_response = metrics_recorder.measure(metric_name('latency')) { execute_message_send(message) }
          build_response raw_response
        end
        metrics_recorder.increment(metric_name('result'), status: 'success')
        response
      rescue StandardError => e
        handle_send_exception(error: e)
      end

      def handle_send_exception(error:)
        raise SMS::BlocklistedNumberError if blocklist_error?(error)

        metrics_recorder.increment(metric_name('result'), status: 'failure')
        notify(error)
        failure_response
      end

      protected

      def execute_message_send(_message)
        raise NotImplementedError, 'OVERRIDE ME!'
      end

      def build_response(_response)
        raise NotImplementedError, 'OVERRIDE ME!'
      end

      def blocklist_error?(_error)
        raise NotImplementedError, 'OVERRIDE ME!'
      end

      def success_response(reference_id:)
        SMS::Response.new(true, self.class.service_name, reference_id, chosen_service_number)
      end

      def failure_response
        SMS::Response.new(false, self.class.service_name, nil, chosen_service_number)
      end

      def chosen_service_number
        @chosen_service_number ||= prefixed_service_numbers.find do |prefix, _service_number|
          destination_number.match?(/^\+?#{prefix}/)
        end&.last || fallback_service_number
      end

      def notify(error)
        notifier&.notify(error)
      end

      def fallback_service_number
        prefixed_service_numbers.to_h.values.first
      end

      def metric_name(name)
        "send_message/#{self.class.service_name}/#{name}"
      end

    end
  end
end
