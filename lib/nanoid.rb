unless defined?(Motion::Project::Config)
  raise "This file must be required within a RubyMotion project Rakefile."
end

require 'motion-support/concern'
require 'motion-support/inflector'
require 'motion-support/core_ext'

Motion::Project::App.setup do |app|
  Dir.glob(File.join(File.dirname(__FILE__), "nanoid/**/*.rb")).each do |file|
    app.files.unshift(file)
  end
end
