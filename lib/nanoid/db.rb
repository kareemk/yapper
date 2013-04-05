class Nanoid::DB
  include Nanoid::Error
  extend  Nanoid::Error

  attr_accessor :store

  def self.default_db(type)
    type ||= :memory

    Thread.current[:db] ||= {}
    Thread.current[:db][type] ||= self.new(:type => type)
  end

  def self.purge
    Thread.list.each do |thread|
      if db = thread[:db]
        db.values.each { |db| db.store.removeAllObjectsFromStoreAndReturnError(nil) }
      end
    end
    true
  end

  def initialize(options)
    error_ptr = Pointer.new(:id)

    case options[:type]
    when :memory
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFMemoryStoreType, path:nil, error: error_ptr)
    when :temp
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFTemporaryStoreType, path:nil, error: error_ptr)
    when :file
      @store = NSFNanoStore.createAndOpenStoreWithType(NSFPersistentStoreType, path:document_path, error: error_ptr)
    else
      raise Nanoid::Error::DB.new("store type must be one of: :memory, :temp or :file")
    end

    raise_if_error(error_ptr)
  end

  private

  def document_path
    NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] + '/default.db'
  end
end
