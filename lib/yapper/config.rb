motion_require 'yapper'

module Yapper::Config
  COLLECTION = '_config'
  extend self

  mattr_accessor :db_version

  def self.get(key)
    Yapper::DB.instance.execute do |txn|
      txn.objectForKey(key.to_s, inCollection: '_config')
    end
  end

  def self.set(key, value)
      Yapper::DB.instance.execute do |txn|
        txn.setObject(value, forKey: key, inCollection: COLLECTION)
      end
  end
end
