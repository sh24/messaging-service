require 'spec_helper'

class TestClient
  def send_sms(_,_,_)
    sleep 10
  end
end

describe SMS do
  subject { SMS.new(message) }
  let(:message) { { to: '4499810123123', msg: 'Test SMS from RSpec' } }

  describe '#send' do
    it "correctly sends with the options given" do
      VCR.use_cassette('voodoo_sms/send') do
        response = SMS.send(message)
        expect(response.success).to be_truthy
      end
    end
  end

  describe '.send' do
    context "when voodoo times out" do

      let(:client) { TestClient.new }

      it "raises a timeout error" do
        allow(VoodooService).to receive(:client).and_return(client)
        expect(Airbrake).to receive(:notify).with(Timeout::Error)
        subject.send(0.001)
      end
    end

    it 'request was successfully received at API' do
      VCR.use_cassette('voodoo_sms/send') do
        response = subject.send
        expect(response.success).to be_truthy
        expect(response.reference_id).to eq "4103395"
        expect(response.service_provider).to eq "voodoo"
      end
    end

    it 'returns false if message fails to send' do
      expect(Airbrake).to receive(:notify)
      expect(SMS.new({ msg: 'SMS body' }).send.success).to be_falsey
    end

    it 'returns false if message fails to send' do
      VCR.use_cassette('voodoo_sms/bad_request') do
        expect(Airbrake).to receive(:notify)
        expect(subject.send.success).to be_falsey
      end
    end

    context 'with fallback enabled' do
      let(:message) { { to: '4499810123123', msg: 'Test SMS from RSpec', with_fallback: true } }

      it 'falls back to another service when the primary service fails' do
        VCR.use_cassette('voodoo_sms/bad_request') do
          VCR.use_cassette('twilio/send') do
            response = subject.send
            expect(response.success).to be_truthy
            expect(response.service_provider).to eq "twilio"
          end
        end
      end

      it 'notifies Airbrake if the fallback fails as well' do
        VCR.use_cassette('voodoo_sms/bad_request') do
          VCR.use_cassette('twilio/bad_request') do
            expect(Airbrake).to receive(:notify)
            expect(subject.send.success).to be_falsey
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
        let(:message) { { to: '4499810123123', msg: 'Test SMS from RSpec', with_fallback: true } }

        it 'tries Twilio first' do
          expect(TwilioService).to receive_message_chain(:client, :account, :messages, :create)
          expect(VoodooService).to_not receive(:client)
          subject.send
        end

        it 'falls back to the usual behaviour if Twilio is down' do
          expect(TwilioService).to receive(:client)
          expect(VoodooService).to receive(:client)
          expect(TwilioService).to receive(:client)
          VCR.use_cassette('twilio/bad_request') { subject.send }
        end
      end

      context 'when fallback is disabled' do
        let(:message) { { to: '4499810123123', msg: 'Test SMS from RSpec', with_fallback: false } }

        it 'still uses Voodoo first' do
          expect(TwilioService).to_not receive(:client)
          expect(VoodooService).to receive(:client)
          subject.send
        end
      end
    end

  end
end
