class Nanoid::DB
  include Nanoid::Error
  extend  Nanoid::Error

  def self.default_db(type)
    type ||= :memory
    @@db ||= self.new(:type => type)
  end

  def self.purge
    @@db.purge
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

    @queue = ::Dispatch::Queue.new("#{NSBundle.mainBundle.bundleIdentifier}.nanoid.main")

    raise_if_error(error_ptr)
  end

  def execute(&block)
    result = []
    @queue.sync { result << block.call(@store) }
    result.first
  end

  def purge
    @store.removeAllObjectsFromStoreAndReturnError(nil)
  end

  private

  def document_path
    NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] + '/default.db'
  end
end
