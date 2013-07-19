unless defined?(Motion::Project::Config)
  raise "This file must be required within a RubyMotion project Rakefile."
end

require 'motion-support/concern'
require 'motion-support/inflector'
require 'motion-support/core_ext'

require 'motion-require'

Motion::Require.all(Dir.glob(File.expand_path('../nanoid/**/*.rb', __FILE__)))

module Nanoid
end
