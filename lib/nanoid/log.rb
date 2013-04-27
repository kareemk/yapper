unless defined?(Log)
  Log = Motion::Log
  Log.addLogger DDTTYLogger.sharedInstance
  Log.addLogger DDASLLogger.sharedInstance
end
