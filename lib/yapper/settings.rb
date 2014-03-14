motion_require 'yapper'

module Yapper::Settings
  PREFIX = 'yapper-'
  extend self

  mattr_accessor :db_version

  def get(key)
    value = storage.objectForKey(storage_key(key))

    # RubyMotion currently has a bug where the strings returned from
    # standardUserDefaults are missing some methods (e.g. to_data).
    # And because the returned object is slightly different than a normal
    # String, we can't just use `value.is_a?(String)`
    value.class.to_s == 'String' ? value.dup : value
  end

  def set(key, value)
    storage.setObject(value, forKey: storage_key(key))
    storage.synchronize
  end

  def delete(key)
    storage.removeObjectForKey(storage_key(key))
    storage.synchronize
  end

  def purge
    storage.dictionaryRepresentation.keys.each { |key| self.delete(key.gsub(/^#{PREFIX}/,'')) if key =~ /^#{PREFIX}/ }
    storage.synchronize
  end

  private

  def storage_key(key)
    "#{PREFIX}#{key}"
  end

  def storage
    NSUserDefaults.standardUserDefaults
  end
end
