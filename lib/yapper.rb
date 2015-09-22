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
    pod 'YapDatabase'      ,'~> 2.7'
    pod 'NSData+MD5Digest' ,'~> 1.0.0'
  end
end
