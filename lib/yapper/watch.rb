class Yapper::Watch
  cattr_accessor :_observer
  cattr_accessor :watches do
    {}
  end

  attr_reader :block

  def self.on_change(notification)
    notifications = Yapper::DB.instance.read_connection.beginLongLivedReadTransaction
    self.watches.values.each { |watch| watch.block.call(notifications) }
  end

  def self.add_watch(&block)
    if watches.empty?
      Yapper::DB.instance.read_connection.beginLongLivedReadTransaction

      _observer = NSNotificationCenter.defaultCenter.addObserver(self,
                                                                 selector: 'on_change:',
                                                                 name: YapDatabaseModifiedNotification,
                                                                 object: nil)
    end

    id = BSON::ObjectId.generate
    self.new(id, &block).tap { |watch| self.watches[id] = watch }
  end

  def initialize(id, &block)
    @id = id
    # XXX Weak Ref?
    @block = block
    self
  end

  def destroy
    watches.delete(@id)

    if watches.empty?
      Yapper::DB.instance.read_connection.endLongLivedReadTransaction
      NSNotificationCenter.defaultCenter.removeObserver(_observer)
    end
  end
end
