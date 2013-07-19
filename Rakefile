require "bundler/gem_tasks"
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/ios'
require 'motion-cocoapods'
require 'motion-logger'
require 'motion-redgreen'
require 'webstub'
require 'nanoid'

Motion::Project::App.setup do |app|
  app.name = 'NanoidDemo'
  app.redgreen_style = :full
  app.pods do
    pod 'NanoStore', '~> 2.6.0'
    pod 'AFNetworking'
    pod 'Reachability'
    pod 'CocoaLumberjack'
    pod 'NSData+MD5Digest'
  end
end

desc "Build the gem"
task :gem do
  sh "bundle exec gem build nanoid.gemspec"
  sh "mkdir -p pkg"
  sh "mv *.gem pkg/"
end
