## SMS messaging service

Using VoodooSMS as primary service and Twilio as fallback.

Install with:

```
gem 'messaging_service', git: 'git@github.com:sh24/messaging-service.git'
```

Example usage:

```
MessagingService::SMS.new(voodoo_credentials: <voodoo_config>, twilio_credentials: <twilio_config>, primary_provider: :voodoo, fallback_provider: :twilio, notifier: Airbrake)
```


Skipping VoodooSMS
==================

Occasionally there have been issues where the VoodooSMS API is accepting messages (and so not triggering the fallback to Twilio) but not actually sending them out.

To combat this, the gem has an override function:

1. Run `touch tmp/OVERRIDE_VOODOO` in the project root

To remove the override and go back to using Voodoo as the primary:

1. Run `rm tmp/OVERRIDE_VOODOO` in the project root

Testing in your application
===========================

So you don't need to VCR all tests that integrate with `MessagingService` then you can stub sending messages like below.

```
let(:sms_response) { double :sms_response, success: true, service_provider: '', reference_id: ''}

before do
  allow_any_instance_of(MessagingService::SMS).to receive(:send).and_return sms_response
end
```
