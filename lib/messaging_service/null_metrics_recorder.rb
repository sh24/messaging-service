# frozen_string_literal: true

module MessagingService
  class NullMetricsRecorder

    def increment(*_args); end

    def gauge(*_args); end

    def timing(*_args); end

    def measure(*_args)
      yield
    end

  end
end
