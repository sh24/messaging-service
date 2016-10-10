require 'spec_helper'

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
  end
end
