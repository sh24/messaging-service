# frozen_string_literal: true

require 'spec_helper'

class TestClient

  def send_sms(_, _, _)
    sleep 10
  end

end

describe MessagingService::SMS do
  let(:voodoo_sender_id){ '440000000000' }
  let(:voodoo_config){ double :voodoo_config, number: voodoo_sender_id, password: 'password', username: 'username' }
  let(:twilio_sender_id){ '440000000000' }
  let(:twilio_config){ double :voodoo_config, number: twilio_sender_id, password: 'auth_token', username: 'account_id' }
  let(:to_number){ '4499810123123' }
  let(:message){ 'Test SMS from RSpec' }
  let(:notifier){ double :notifier, notify: true }
  subject{ described_class.new(voodoo: voodoo_config, notifier: notifier) }

  describe '#send' do
    context 'when voodoo times out' do
      let(:client){ TestClient.new }

      it 'raises a timeout error' do
        allow(VoodooSMS).to receive(:new).and_return(client)
        expect(notifier).to receive(:notify).with(Timeout::Error)
        subject.send(timeout: 0.001, to: to_number, message: message)
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

    it 'returns false if message fails to send' do
      expect(notifier).to receive(:notify)
      expect(MessagingService::SMS.new(voodoo: nil, notifier: notifier).send(to: to_number, message: message).success).to be false
    end

    it 'returns false if message fails to send' do
      VCR.use_cassette('voodoo_sms/bad_request') do
        expect(notifier).to receive(:notify)
        expect(subject.send(to: to_number, message: message).success).to be_falsey
      end
    end

    context 'with fallback enabled' do
      subject{ described_class.new(voodoo: voodoo_config, fallback_twilio: twilio_config, notifier: notifier) }

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
        subject{ described_class.new(voodoo: voodoo_config, fallback_twilio: twilio_config, notifier: notifier) }

        it 'tries Twilio first' do
          expect(Twilio::REST::Client).to receive_message_chain(:new, :account, :messages, :create)
          expect(VoodooSMS).to_not receive(:new)
          response = subject.send(to: to_number, message: message)
          expect(response.service_provider).to eq 'twilio'
        end

        it 'falls back to the usual behaviour if Twilio is down' do
          expect(Twilio::REST::Client).to receive(:new)
          expect(VoodooSMS).to receive(:new)
          expect(Twilio::REST::Client).to receive(:new)
          VCR.use_cassette('twilio/bad_request'){ subject.send(to: to_number, message: message) }
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
