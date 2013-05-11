module Nanoid; module Sync; class Queue
  @@included = false

  # XXX Hack to get around load order
  def self._include
    unless @@included
      include Nanoid::Document
      store_in :file

      field :sync_class
      field :sync_id
      field :created_at
      field :failure_count

      @@inclued = true
    end
  end

  def self.<<(instance)
    self._include

    instance.update_attributes({:_sync_in_progress => true}, :skip_callbacks => true)
    self.notification(instance, 'start')
    self.create(:sync_class => instance.class.to_s,
                :sync_id => instance.id,
                :created_at => Time.now.utc,
                :failure_count => 0)
    self.notify
  end

  def self.notify
    self._include

    @@queue ||= ::Dispatch::Queue.new("#{NSBundle.mainBundle.bundleIdentifier}.nanoid.sync")
    @@mutex ||= Mutex.new
    @@notify_count ||= 0

    @@mutex.synchronize do
      @@notify_count += 1
    end

    cb = proc do
      while @@notify_count > 0
        while job = asc(:created_at).first
          instance = Object.qualified_const_get(job.sync_class).find(job.sync_id)
          if instance.updated_at > (instance._synced_at || Time.at(0))
            job.attempt(instance, :post_or_put)
          else
            job.attempt(instance, :get)
          end
        end

        @@mutex.synchronize do
          @@notify_count -= 1
        end
      end
    end

    @@queue.async(&cb)
    nil
  end

  def attempt(instance, method)
    case instance.send(method)
    when :success
      instance.update_attributes({:_synced_at => Time.now, :_sync_in_progress => false}, :skip_callbacks => true)
      self.destroy
      self.class.notification(instance, 'success')
    when :failure
      if self.failure_count < Nanoid::Sync.max_failure_count
        self.failure_count += 1
        self.save
        self.class.notification(instance, 'retry')
      else
        Log.error "[Nanoid::Queue][CRITICAL] Job #{self.sync_class}:#{self.sync_id} exceeded failure threshold and has been removed"
        self.destroy
        self.class.notification(instance, 'failure')
      end
    when :critical
      instance.update_attributes({:_sync_in_progress => false}, :skip_callbacks => true)
      self.destroy
      self.class.notification(instance, 'failure')
    end
  end

  private

  def self.notification(instance, type)
      NSNotificationCenter.defaultCenter.postNotificationName("nanoid:#{instance._type.downcase}:sync:#{type}", object: instance.id , userInfo: nil)
  end
end; end; end
