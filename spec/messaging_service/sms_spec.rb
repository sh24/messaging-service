# frozen_string_literal: true

require 'spec_helper'

class TestClient

  def send_sms(_, _, _)
    sleep 10
  end

end

describe MessagingService::SMS do
  let(:voodoo_credentials){ { number: '440000000000', password: 'password', username: 'username' } }
  let(:twilio_credentials){ { number: '440000000000', password: 'auth_token', username: 'account_id' } }
  let(:to_number){ '4499810123123' }
  let(:message){ 'Test SMS from RSpec' }
  let(:notifier){ double :notifier, notify: true }

  subject{ described_class.new voodoo_credentials: voodoo_credentials, primary_provider: :voodoo, notifier: notifier }

  describe '#send' do
    context 'when voodoo times out' do
      let(:client){ TestClient.new }

      it 'raises a timeout error' do
        allow(VoodooSMS).to receive(:new).and_return(client)
        expect(notifier).to receive(:notify).with(Timeout::Error)
        subject.send timeout: 0.001, to: to_number, message: message
      end
    end

    it 'request was successfully received at API' do
      VCR.use_cassette('voodoo_sms/send') do
        response = subject.send(to: to_number, message: message)
        expect(response.success).to be_truthy
        expect(response.reference_id).to eq '4103395'
        expect(response.service_provider).to eq 'voodoo'
      end
    end

    it 'raises an argument error if no credentials are provided' do
      expect{ MessagingService::SMS.new(voodoo_credentials: nil, primary_provider: :voodoo, notifier: notifier) }.to raise_error(ArgumentError)
    end

    it 'returns false if message fails to send' do
      VCR.use_cassette('voodoo_sms/bad_request') do
        expect(notifier).to receive(:notify)
        expect(subject.send(to: to_number, message: message).success).to be_falsey
      end
    end

    context 'with twilio as primary' do
      subject{ described_class.new twilio_credentials: twilio_credentials, primary_provider: :twilio, notifier: notifier }

      it 'sends an sms with twilio' do
        VCR.use_cassette('twilio/send') do
          response = subject.send(to: to_number, message: message)
          expect(response.success).to be_truthy
          expect(response.reference_id).to eq 'SM0b54a4a40c4d42c9a518a7cdc18c5647'
          expect(response.service_provider).to eq 'twilio'
        end
      end

      context 'when twilio is down and voodoo is set as fallback provider' do
        subject do
          described_class.new(
            voodoo_credentials: voodoo_credentials,
            twilio_credentials: twilio_credentials,
            primary_provider:   :twilio,
            fallback_provider:  :voodoo,
            notifier:           notifier
          )
        end

        it 'sends with voodoo' do
          VCR.use_cassette('twilio/bad_request') do
            VCR.use_cassette('voodoo_sms/send') do
              response = subject.send(to: to_number, message: message, timeout: 15)
              expect(response.success).to be_truthy
              expect(response.service_provider).to eq 'voodoo'
            end
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
          primary_provider:   :voodoo,
          fallback_provider:  :twilio,
          notifier:           notifier
        )
      end

      it 'falls back to another service when the primary service fails' do
        VCR.use_cassette('voodoo_sms/bad_request') do
          VCR.use_cassette('twilio/send') do
            response = subject.send(to: to_number, message: message)
            expect(response.success).to be_truthy
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

    context "when #{described_class::OVERRIDE_VOODOO_FILE} exists" do
      around do |test|
        FileUtils.mkdir('tmp')
        FileUtils.touch described_class::OVERRIDE_VOODOO_FILE
        test.run
        FileUtils.rm described_class::OVERRIDE_VOODOO_FILE
        FileUtils.rm_r 'tmp'
      end

      context 'when fallback is enabled' do
        subject do
          described_class.new(
            voodoo_credentials: voodoo_credentials,
            twilio_credentials: twilio_credentials,
            primary_provider:   :voodoo,
            fallback_provider:  :twilio,
            notifier:           notifier
          )
        end

        it 'tries Twilio first' do
          expect(Twilio::REST::Client).to receive_message_chain(:new, :account, :messages, :create)
          expect(VoodooSMS).to_not receive(:new)
          response = subject.send(to: to_number, message: message)
          expect(response.service_provider).to eq 'twilio'
        end

        it 'falls back to the usual behaviour if Twilio is down' do
          expect(Twilio::REST::Client).to receive(:new).and_call_original
          expect(VoodooSMS).to receive(:new).and_call_original
          VCR.use_cassette('twilio/bad_request') do
            VCR.use_cassette('voodoo_sms/send') do
              subject.send to: to_number, message: message, timeout: 15
            end
          end
        end
      end

      context 'when fallback is disabled' do
        it 'still uses Voodoo first' do
          expect(Twilio::REST::Client).to_not receive(:new)
          expect(VoodooSMS).to receive(:new)
          subject.send(to: to_number, message: message)
        end
      end
    end
  end
end
