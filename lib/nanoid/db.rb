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

  def self.default
    get(:default)
  end

  def initialize(options)
    @options = options
    @name = options[:name]
    self
  end

  def execute(&block)
    block.call(_store)
  end

  def transaction(&block)
    error_ptr = Pointer.new(:id)
    execute { |store| store.beginTransactionAndReturnError(error_ptr) }
    raise_if_error(error_ptr)

    begin
      block.call
    rescue StandardError => e
      execute { |store| store.rollbackTransactionAndReturnError(error_ptr) }
      raise e
    end
    success = execute { |store| store.commitTransactionAndReturnError(error_ptr) }
    raise_if_error(error_ptr)

    success
  end

  def batch(&block)
    # XXX THIS NEEDS TO BE THREAD SAFE. NEED A SEPERATE CONNECTION PER THREAD
    execute do |store|
      store.setSaveInterval(10000000)
    end

    Nanoid::Document::Callbacks.postpone_callbacks do
      block.call
      execute do |store|
        error_ptr = Pointer.new(:id)
        store.saveStoreAndReturnError(error_ptr)
        store.setSaveInterval(1)
        raise_if_error(error_ptr)
      end
    end
  end

  def purge
    error_ptr = Pointer.new(:id)
    _store.removeAllObjectsFromStoreAndReturnError(error_ptr)
    raise_if_error(error_ptr)
  end

  private

  def _store
    Thread.current[:store] ||= begin
      error_ptr = Pointer.new(:id)
      store = nil
      case @options[:type]
      when :memory
        store = NSFNanoStore.createAndOpenStoreWithType(NSFMemoryStoreType, path:nil, error: error_ptr)
      when :temp
        store = NSFNanoStore.createAndOpenStoreWithType(NSFTemporaryStoreType, path:nil, error: error_ptr)
      when :file
        store = NSFNanoStore.createAndOpenStoreWithType(NSFPersistentStoreType, path:document_path, error: error_ptr)
      else
        raise Nanoid::Error::DB.new("store type must be one of: :memory, :temp or :file")
      end

      raise_if_error(error_ptr)
      store
    end
  end


  def _queue
    Thread.current[:queue] ||= begin
      queue = NSOperationQueue.alloc.init
      queue.name = "#{NSBundle.mainBundle.bundleIdentifier}.nanoid.#{@name}"
      queue.MaxConcurrentOperationCount = 1
      queue
    end
  end

  def document_path
    NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] + "/#{@name}.db"
  end
end
