class Yapper::Watch
  cattr_accessor :_observer
  cattr_accessor :watches do
    {}
  end

  attr_reader :block

  class << self
    def on_change(notification)
      notifications = db.read_connection.beginLongLivedReadTransaction
      self.watches.values.each { |watch| watch.block.call(notifications) }
    end

    def add(mapping=nil, &block)
      if watches.empty?
        Yapper::DB.instance.read_connection.beginLongLivedReadTransaction

      db.read { |txn| mapping.updateWithTransaction(txn) } if mapping
        _observer = NSNotificationCenter.defaultCenter.addObserver(self,
                                                                   selector: 'on_change:',
                                                                   name: YapDatabaseModifiedNotification,
                                                                   object: nil)
      end

      id = BSON::ObjectId.generate
      self.new(id, &block).tap { |watch|  self.watches[id] = watch }
    end

    def db
      Yapper::DB.instance
    end
  end

  def initialize(id, &block)
    @id = id
    # XXX Weak Ref?
    @block = block
    self
  end

  def end
    watches.delete(@id)

    if watches.empty?
      Yapper::DB.instance.read_connection.endLongLivedReadTransaction
      NSNotificationCenter.defaultCenter.removeObserver(_observer)
    end
  end
end
