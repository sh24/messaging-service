# frozen_string_literal: true

require 'spec_helper'

module  MessagingService
  module Integrations

    describe VoodooIntegration do
      describe '#send_message' do
        let(:prefixed_service_numbers) { {} }
        let(:destination_number) { '01234567890' }
        let(:error_notifier) { double('notifier') }
        let(:metrics_recorder) { double('metrics_recorder') }

        before do
          allow(error_notifier).to receive(:notify)
          allow(metrics_recorder).to receive(:increment)
          allow(metrics_recorder).to receive(:measure).and_yield
        end

        subject do
          described_class.new(
            'user',
            'password',
            prefixed_service_numbers,
            destination_number,
            error_notifier,
            metrics_recorder: metrics_recorder
          )
        end

        context 'when the voodoo integration is disabled' do
          before do
            ENV['VOODOO_DISABLE_MESSAGING'] = 'true'
          end

          after do
            ENV.delete('VOODOO_DISABLE_MESSAGING')
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

        it 'records metrics' do
          subject.send_message('message')
          expect(metrics_recorder).to have_received(:increment).with('send_message/voodoo/result', status: 'failure')
          expect(metrics_recorder).to have_received(:measure).with('send_message/voodoo/latency')
        end
      end
    end

  end
end
