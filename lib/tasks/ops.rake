require 'fileutils'

namespace :ops do
  desc 'Override VoodooSMS usage'
  task voodoo_off: :environment do
    FileUtils.touch(SMS::OVERRIDE_VOODOO_FILE)
    puts "Voodoo overriden: flag file present"
  end

  desc 'Reinstate VoodooSMS usage'
  task voodoo_on: :environment do
    if File.exists?(SMS::OVERRIDE_VOODOO_FILE)
      FileUtils.rm(SMS::OVERRIDE_VOODOO_FILE)
      puts "Voodoo active: flag file not present"
    else
      puts "Nothing changed"
    end
  end
end
