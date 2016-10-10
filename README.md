## SMS messaging service

Using VoodooSMS as primary service and Twilio as fallback.

Install with:

```
gem 'messaging_service', git: 'git@github.com:sh24/messaging-service.git'
```


Configure VoodooSMS and Twilio auth with [rails_config](https://github.com/railsconfig/rails_config) and set:

```
Settings.voodoo_sms.username
Settings.voodoo_sms.password
Settings.voodoo_sms.sender_id
Settings.twilio.account_id
Settings.twilio.auth_token
Settings.twilio.sms_number
```

Example usage:

```
SMS.send({ to: "44123123123", msg: "My message" })
```


Skipping VoodooSMS
==================

Occasionally there have been issues where the VoodooSMS API is accepting messages (and so not triggering the fallback to Twilio) but not actually sending them out.

To combat this, the gem has an override function:

1. Run `touch tmp/OVERRIDE_VOODOO` in the project root

To remove the override and go back to using Voodoo as the primary:

1. Run `rm tmp/OVERRIDE_VOODOO` in the project root
