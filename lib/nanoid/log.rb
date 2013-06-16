if defined?(Motion::Nanoid::Log)
  Nanoid::Nanoid::Log = Motion::Nanoid::Log
  Nanoid::Log.addNanoid::Logger DDTTYNanoid::Logger.sharedInstance
  Nanoid::Log.addNanoid::Logger DDASLNanoid::Logger.sharedInstance
end
