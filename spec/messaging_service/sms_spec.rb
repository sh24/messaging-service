# frozen_string_literal: true

require 'spec_helper'

class TestClient

  def send_sms(*_args)
    # Used by timeout error test
    sleep 1
  end

end

describe MessagingService::SMS do
  subject do
    described_class.new credentials: credentials,
                        primary_provider: :voodoo, notifier: notifier,
                        metrics_recorder: metrics_recorder
  end

  let(:english_number) { '440000000000' }
  let(:irish_number) { '3530000000000' }
  let(:configured_numbers) { { '44': english_number, '353': irish_number } }
  let(:voodoo_credentials){ { numbers: configured_numbers, password: 'password', username: 'username' } }
  let(:twilio_credentials){ { numbers: configured_numbers, password: 'token', username: 'account' } }
  let(:to_number){ '447799323232' }
  let(:message){ 'Test SMS from RSpec' }
  let(:notifier){ double :notifier, notify: true }
  let(:metrics_recorder) { double('metrics') }
  let(:credentials) do
    [
      { provider: :twilio, numbers: configured_numbers, password: 'password', username: 'username' },
      { provider: :voodoo, numbers: configured_numbers, password: 'token', username: 'account' },
    ]
  end

  before do
    allow(metrics_recorder).to receive(:increment)
    allow(metrics_recorder).to receive(:measure).and_yield
  end

  describe '#send' do
    context 'when sending to an irish number' do
      let(:to_number){ '3537799323232' }
      let(:client) { instance_double(VoodooSMS) }

      it 'uses the irish source number' do
        allow(VoodooSMS).to receive(:new).and_return(client)
        expect(client).to receive(:send_sms).with(irish_number, to_number, message)

        subject.send to: to_number, message: message
      end
    end

    context 'when sending to an english number' do
      let(:to_number){ '447799323232' }
      let(:client) { instance_double(VoodooSMS) }

      it 'uses the english source number' do
        allow(VoodooSMS).to receive(:new).and_return(client)
        expect(client).to receive(:send_sms).with(english_number, to_number, message)

        subject.send to: to_number, message: message
      end
    end

    context 'when sending to an azerbaijan number' do
      let(:to_number){ '9947799323232' }
      let(:client) { instance_double(VoodooSMS) }

      it 'uses the english source number' do
        allow(VoodooSMS).to receive(:new).and_return(client)
        expect(client).to receive(:send_sms).with(english_number, to_number, message)

        subject.send to: to_number, message: message
      end
    end

    context 'when voodoo times out' do
      let(:client){ TestClient.new }

      around do |example|
        override_integration_timeout 0.1
        example.run
        override_integration_timeout 15
      end

      before do
        allow(VoodooSMS).to receive(:new).and_return(client)
        expect(notifier).to receive(:notify).with(Timeout::Error)
      end

      it 'raises a timeout error' do
        subject.send to: to_number, message: message
      end

      it 'reports an error count' do
        subject.send to: to_number, message: message
        expect(metrics_recorder).to have_received(:increment).with('send_message/voodoo/result', status: 'failure')
      end
    end

    context 'when Voodoo raises a blocklist error' do
      let(:client){ TestClient.new }

      it 'does not suppress the error' do
        expect(VoodooSMS).to receive(:new).and_return(client)
        expect(client).to receive(:send_sms).and_raise(VoodooSMS::Error::BadRequest, '400, Black List Number Found')

        expect { subject.send(to: '447870123456', message: 'Hello') }.to raise_error MessagingService::SMS::BlocklistedNumberError
      end
    end

    it 'request was successfully received at API' do
      VCR.use_cassette('voodoo_sms/send') do
        response = subject.send(to: to_number, message: message)
        expect(response.success).to be true
        expect(response.reference_id).to eq '4103395'
        expect(response.service_provider).to eq 'voodoo'
      end
    end

    it 'raises an argument error if no credentials are provided' do
      expect{ described_class.new(voodoo_credentials: nil, primary_provider: :voodoo, notifier: notifier) }.to raise_error(ArgumentError)
    end

    it 'returns false if message fails to send' do
      VCR.use_cassette('voodoo_sms/bad_request') do
        expect(notifier).to receive(:notify)
        expect(subject.send(to: to_number, message: message).success).to be_falsey
      end
    end

    context 'with twilio as primary' do
      subject{ described_class.new twilio_credentials: twilio_credentials, primary_provider: :twilio, notifier: notifier, metrics_recorder: metrics_recorder }

      it 'sends an SMS with twilio' do
        VCR.use_cassette('twilio/send') do
          response = subject.send(to: to_number, message: message)
          expect(response.success).to be true
          expect(response.reference_id).to eq 'SM4225c983dae74e3da79fc5c3f15a826b'
          expect(response.service_provider).to eq 'twilio'
        end
      end

      it 'records metrics' do
        VCR.use_cassette('twilio/send') do
          subject.send(to: to_number, message: message)
          expect(metrics_recorder).to have_received(:increment).with('send_message/twilio/result', status: 'success')
          expect(metrics_recorder).to have_received(:measure).with('send_message/twilio/latency')
        end
      end

      context 'when twilio is down and voodoo is set as fallback provider' do
        subject do
          described_class.new(
            voodoo_credentials: voodoo_credentials,
            twilio_credentials: twilio_credentials,
            primary_provider: :twilio,
            notifier: notifier,
            metrics_recorder: metrics_recorder
          )
        end

        it 'records metrics' do
          VCR.use_cassette('twilio/bad_request') do
            subject.send(to: to_number, message: message)
            expect(metrics_recorder).to have_received(:increment).with('send_message/twilio/result', status: 'failure')
          end
        end

        it 'sends with voodoo' do
          VCR.use_cassette('twilio/bad_request') do
            VCR.use_cassette('voodoo_sms/send') do
              response = subject.send(to: to_number, message: message)
              expect(response.success).to be true
              expect(response.service_provider).to eq 'voodoo'
            end
          end
        end
      end

      context 'twilio is down and there is no fallback provider' do
        subject do
          described_class.new(
            twilio_credentials: twilio_credentials,
            primary_provider: :twilio,
            notifier: notifier
          )
        end

        it 'fails to send' do
          VCR.use_cassette('twilio/bad_request') do
            response = subject.send(to: to_number, message: message)
            expect(response.success).to be false
            expect(response.service_provider).to eq 'twilio'
          end
        end
      end
    end

    context 'without a notifier' do
      subject{ described_class.new voodoo_credentials: voodoo_credentials, primary_provider: :voodoo }

      it 'still works, but does not call the notifier' do
        VCR.use_cassette('voodoo_sms/bad_request') do
          expect(notifier).not_to receive(:notify)
          expect(subject.send(to: to_number, message: message).success).to be_falsey
        end
      end
    end

    context 'with fallback enabled' do
      subject do
        described_class.new(
          voodoo_credentials: voodoo_credentials,
          twilio_credentials: twilio_credentials,
          primary_provider: :voodoo,
          notifier: notifier
        )
      end

      it 'falls back to another service when the primary service fails' do
        VCR.use_cassette('voodoo_sms/bad_request') do
          VCR.use_cassette('twilio/send') do
            response = subject.send(to: to_number, message: message)
            expect(response.success).to be true
            expect(response.service_provider).to eq 'twilio'
          end
        end
      end

      it 'notifies notifier if the fallback fails as well' do
        VCR.use_cassette('voodoo_sms/bad_request') do
          VCR.use_cassette('twilio/bad_request') do
            expect(notifier).to receive(:notify)
            expect(subject.send(to: to_number, message: message).success).to be_falsey
          end
        end
      end
    end

    context 'when the voodoo integration is disabled' do
      before do
        ENV['VOODOO_DISABLE_MESSAGING'] = 'true'
      end

      after do
        ENV.delete('VOODOO_DISABLE_MESSAGING')
      end

      context 'when fallback is not enabled' do
        subject do
          described_class.new(
            voodoo_credentials: voodoo_credentials,
            twilio_credentials: twilio_credentials,
            primary_provider: :voodoo,
            notifier: notifier
          )
        end

        it 'does not send the message' do
          expect(Twilio::REST::Client).not_to receive(:new)
          expect(VoodooSMS).not_to receive(:new)
          response = subject.send(to: to_number, message: message)
          expect(response.success).to be false
          expect(response.service_provider).to eq 'voodoo'
        end
      end

      context 'when fallback is enabled' do
        subject do
          described_class.new(
            voodoo_credentials: voodoo_credentials,
            twilio_credentials: twilio_credentials,
            primary_provider: :voodoo,
            notifier: notifier
          )
        end

        it 'tries Twilio first' do
          expect(Twilio::REST::Client).to receive_message_chain(:new, :api, :account, :messages, :create)
          expect(VoodooSMS).not_to receive(:new)
          response = subject.send(to: to_number, message: message)
          expect(response.service_provider).to eq 'twilio'
        end

        it 'fails if Twilio is down' do
          expect(Twilio::REST::Client).to receive(:new).and_call_original
          expect(VoodooSMS).not_to receive(:new)
          VCR.use_cassette('twilio/bad_request') do
            response = subject.send to: to_number, message: message
            expect(response.success).to be false
            expect(response.service_provider).to eq 'voodoo'
          end
        end
      end

      context 'when fallback is disabled' do
        it 'fails' do
          expect(Twilio::REST::Client).not_to receive(:new)
          expect(VoodooSMS).not_to receive(:new)
          response = subject.send(to: to_number, message: message)
          expect(response.success).to be false
          expect(response.service_provider).to eq 'voodoo'
        end
      end
    end

    context 'when sending via Twilio' do
      subject do
        described_class.new(
          twilio_credentials: twilio_credentials,
          primary_provider: :twilio
        )
      end

      context 'when the destination number has no + before a supported country code' do
        let(:to_number){ '447799323232' }

        it 'appends a +' do
          expect(Twilio::REST::Client)
            .to receive_message_chain(:new, :api, :account, :messages, :create)
            .with(hash_including(to: "+#{to_number}"))

          subject.send(to: to_number, message: message)
        end
      end

      context 'when the destination number already has a + before a supported country code' do
        let(:to_number){ '+491747820400' }

        it 'does not append a +' do
          expect(Twilio::REST::Client)
            .to receive_message_chain(:new, :api, :account, :messages, :create)
            .with(hash_including(to: to_number))

          subject.send(to: to_number, message: message)
        end
      end

      context 'when Twilio raises a blocklist error' do
        let(:to_number){ '447799323232' }

        it 'raises a blocklist error' do
          VCR.use_cassette('twilio/blocklisted_bad_request') do
            expect { subject.send(to: '+447799323232', message: 'Hello') }.to raise_error MessagingService::SMS::BlocklistedNumberError
          end
        end
      end
    end
  end

  def override_integration_timeout(value = 15)
    verbosity = $VERBOSE
    $VERBOSE = nil
    MessagingService::Integrations::BaseIntegration.const_set :RESPONSE_TIMEOUT_SECONDS, value
    $VERBOSE = verbosity
  end
end
