class Nanoid::DB
  include Nanoid::Error
  extend  Nanoid::Error

  @@dbs   = {}
  @@queue = Dispatch::Queue.new("#{NSBundle.mainBundle.bundleIdentifier}.nanoid.#{@name}")

  def self.get(name)
    @@queue.sync do
      @@dbs[name] ||= self.new(:name => name, :type => :file)
    end
    @@dbs[name]
  end

  def self.purge
    @@dbs.values.each(&:purge)
    true
  end

  def initialize(options)
    @name = options[:name]

    @queue = NSOperationQueue.alloc.init
    @queue.name = "#{NSBundle.mainBundle.bundleIdentifier}.nanoid.#{@name}"
    @queue.MaxConcurrentOperationCount = 1

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

  def execute(&block)
    result = []
    operation = NSBlockOperation.blockOperationWithBlock lambda { result << block.call(@store) }
    priority =  NSThread.isMainThread ? NSOperationQueuePriorityHigh : NSOperationQueuePriorityLow
    operation.setQueuePriority(priority)
    @queue.addOperation(operation)
    operation.waitUntilFinished
    result.first
  end

  def purge
    error_ptr = Pointer.new(:id)
    @store.removeAllObjectsFromStoreAndReturnError(error_ptr)
    raise_if_error(error_ptr)
  end

  private

  def document_path
    NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] + "/#{@name}.db"
  end
end
