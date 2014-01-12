if defined?(Motion::Yapper::Log)
  Yapper::Yapper::Log = Motion::Yapper::Log
  Yapper::Log.addYapper::Logger DDTTYYapper::Logger.sharedInstance
  Yapper::Log.addYapper::Logger DDASLYapper::Logger.sharedInstance
end
