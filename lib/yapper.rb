unless defined?(Motion::Project::Config)
  raise "This file must be required within a RubyMotion project Rakefile."
end

require 'motion-require'
require 'motion-support/concern'
require 'motion-support/inflector'
require 'motion-support/core_ext'

files = Dir.glob(File.expand_path('../../lib/yapper/**/*.rb', __FILE__))
Motion::Require.all(files)

Motion::Project::App.setup do |app|
  app.detect_dependencies = false

  app.pods do
    pod 'YapDatabase'      ,'~> 2.3'
    pod 'CocoaLumberjack'  ,'~> 1.6.5'
    pod 'NSData+MD5Digest' ,'~> 1.0.0'
  end

  yap_patch = File.expand_path(File.join(File.dirname(__FILE__), '../vendor/YapDatabaseRubyMotion'))
  app.vendor_project(yap_patch,
                     :static,
                     :bridgesupport_cflags => "-I#{Dir.pwd}/vendor/Pods/Headers -fobjc-arc",
                     :cflags => "-I#{Dir.pwd}/vendor/Pods/Headers -fobjc-arc")

end
