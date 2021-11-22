# frozen_string_literal: true

require 'spec_helper'

module  MessagingService
  module Integrations

    describe VoodooIntegration do
      describe '#send_message' do
        context 'when the voodoo integration is disabled' do
          let(:prefixed_service_numbers) { {} }
          let(:destination_number) { '01234567890' }
          let(:error_notifier) { double('notifier') }

          before do
            ENV['VOODOO_DISABLE_MESSAGING'] = 'true'
            allow(error_notifier).to receive(:notify)
          end

          after do
            ENV.delete('VOODOO_DISABLE_MESSAGING')
          end

          subject do
            described_class.new(
              'user',
              'password',
              prefixed_service_numbers,
              destination_number,
              error_notifier
            )
          end

          it 'returns a failed status report' do
            result = subject.send_message('message')
            expect(result.success).to eq false
          end

          it 'reports an error' do
            subject.send_message('message')
            expect(error_notifier).to have_received(:notify)
          end
        end
      end
    end

  end
end
