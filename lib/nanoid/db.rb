class Nanoid::DB
  attr_accessor :store

  def initialize(options)
    error = Pointer.new(:id)

    case options[:type]
    when :memory
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFMemoryStoreType, path:nil, error: error)
    when :temp
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFTemporaryStoreType, path:nil, error: error)
    when :file
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFPersistentStoreType, path:options[:path], error: error)
    else
      raise Error::DB.new("store type must be one of: :memory, :temp or :file")
    end

    raise Error::DB, error[0].description if error[0]
  end
end
