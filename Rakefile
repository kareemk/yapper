require "bundler/gem_tasks"
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/ios'
require 'motion-cocoapods'
require 'motion-logger'
require 'motion-redgreen'
require 'motion-support/concern'
require 'motion-support/inflector'
require 'motion-support/core_ext'
require 'webstub'

Motion::Project::App.setup do |app|
  app.name = 'NanoidDemo'
  app.redgreen_style = :full
  app.files += Dir.glob(File.join(app.project_dir, 'lib/nanoid/**/*.rb'))
  app.files = (app.files + Dir.glob('./app/**/*.rb')).uniq
  app.pods do
    pod 'NanoStore', '~> 2.6.0'
    pod 'AFNetworking'
    pod 'CocoaLumberjack'
  end
end

desc "Build the gem"
task :gem do
  sh "bundle exec gem build nanoid.gemspec"
  sh "mkdir -p pkg"
  sh "mv *.gem pkg/"
end
