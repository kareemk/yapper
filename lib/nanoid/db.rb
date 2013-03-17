class Nanoid::DB
  include Nanoid::Error

  attr_accessor :store

  def initialize(options)
    error_ptr = Pointer.new(:id)

    case options[:type]
    when :memory
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFMemoryStoreType, path:nil, error: error_ptr)
    when :temp
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFTemporaryStoreType, path:nil, error: error_ptr)
    when :file
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFPersistentStoreType, path:options[:path], error: error_ptr)
    else
      raise Nanoid::Document::Error::DB.new("store type must be one of: :memory, :temp or :file")
    end

    raise_if_error(error_ptr)
  end

  def self.default_db
    @@default_db ||= self.new(type: :memory)
    @@default_db
  end

  def self.purge
    default_db.store.removeAllObjectsFromStoreAndReturnError(nil)
  end
end
