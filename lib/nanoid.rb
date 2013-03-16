unless defined?(Motion::Project::Config)
  raise "This file must be required within a RubyMotion project Rakefile."
end

Motion::Project::App.setup do |app|
  Dir.glob(File.join(File.dirname(__FILE__), 'nanoid/*.rb')).each do |file|
    app.files.unshift(file)
  end

  app.pods ||= Motion::Project::CocoaPods.new(app)
  app.pods.pod 'NanoStore', '~> 2.6.0'
end

module Nanoid
  class << self
    attr_accessor :db

    def configure(options)
      self.db = DB.new(options)
    end
  end
end
