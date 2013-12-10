class Nanoid::DB
  include Nanoid::Error
  extend  Nanoid::Error

  @@dbs   = {}
  @@queue = Dispatch::Queue.new("#{NSBundle.mainBundle.bundleIdentifier}.nanoid.db#{@name}")

  def self.get(name)
    @@dbs[name] || begin
                     @@queue.sync do
                       @@dbs[name] ||= self.new(:name => name, :type => :file)
                     end
                     @@dbs[name]
                   end
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
    _queue; _store

    self
  end

  def execute(&block)
    if running?
      block.call(_store)
    else
      _run { |store| block.call(store) }
    end
  end

  def transaction(&block)
    execute do |store|
      error_ptr = Pointer.new(:id)
      store.beginTransactionAndReturnError(error_ptr)
      raise_if_error(error_ptr)

      begin
        block.call
      rescue NSException => e
        store.rollbackTransactionAndReturnError(error_ptr)
        raise e
      end
      success = store.commitTransactionAndReturnError(error_ptr)
      raise_if_error(error_ptr)

      success
    end
  end

  def batch(&block)
    execute do |store|
      store.setSaveInterval(10000000)
      Nanoid::Document::Callbacks.postpone_callbacks do
        block.call
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

  def running=(value)
    Thread.current[:nanoid_running] = value
  end

  def running?
    Thread.current[:nanoid_running]
  end

  def _run(&block)
    result = nil
    _queue.sync do
      self.running = true
      begin
        result = block.call(_store)
      rescue NSException => e
        result = e
      ensure
        self.running = false
      end
    end

    raise result if result.is_a?(NSException)
    result
  end

  def _store
    @store ||= begin
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
    @queue ||= Dispatch::Queue.new("#{NSBundle.mainBundle.bundleIdentifier}.nanoid.#{@name}")
  end

  def document_path
    NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] + "/#{@name}.db"
  end
end
