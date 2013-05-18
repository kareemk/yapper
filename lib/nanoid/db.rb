class Nanoid::DB
  include Nanoid::Error
  extend  Nanoid::Error

  @@db = nil

  def self.default_db(type)
    type ||= :memory
    @@db ||= self.new(:type => type)
  end

  def self.purge
    @@db.purge if @@db
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

    @queue = NSOperationQueue.alloc.init
    @queue.name = "#{NSBundle.mainBundle.bundleIdentifier}.nanoid.main"
    @queue.MaxConcurrentOperationCount = 1

    raise_if_error(error_ptr)
  end

  def execute(&block)
    result = []
    operation = NSBlockOperation.blockOperationWithBlock lambda { result << block.call(@store) }
    @queue.addOperation(operation)
    operation.waitUntilFinished
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
