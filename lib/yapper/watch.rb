class Yapper::Watch
  cattr_accessor :_observer
  cattr_accessor :watches do
    {}
  end

  attr_reader :mapping
  attr_reader :block

  class << self
    def on_change(notification)
      notifications = db.read_connection.beginLongLivedReadTransaction
      self.watches.values.each do |watch|
        watch.block.call(notifications) if watch.block rescue WeakRef::RefError
      end
    end

    def add(mapping=nil, &block)
      if watches.empty?
        db.read_connection.beginLongLivedReadTransaction
        _observer = NSNotificationCenter.defaultCenter.addObserver(self,
                                                                   selector: 'on_change:',
                                                                   name: YapDatabaseModifiedNotification,
                                                                   object: nil)
      end
      db.read { |txn| mapping.updateWithTransaction(txn) } if mapping

      id = BSON::ObjectId.generate
      self.new(id, mapping, &block).tap { |watch|  self.watches[id] = watch }
    end

    def db
      Yapper::DB.instance
    end
  end

  def initialize(id, mapping, &block)
    @id = id
    # XXX Weak Ref?
    @block = block
    @mapping = mapping
    self
  end

  def end
    watches.delete(@id)

    @block = nil
    @mapping = nil

    if watches.empty?
      Yapper::DB.instance.read_connection.endLongLivedReadTransaction
      NSNotificationCenter.defaultCenter.removeObserver(_observer)
    end
  end
end
