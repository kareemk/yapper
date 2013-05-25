module Nanoid; module Sync; class Queue
  @@included = false
  @@queue = ::Dispatch::Queue.new("#{NSBundle.mainBundle.bundleIdentifier}.nanoid.sync")
  @@mutex = Mutex.new
  @@notify_count = 0

  # XXX Hack to get around load order
  def self._include
    unless @@included
      include Nanoid::Document

      field :sync_class
      field :sync_id
      field :created_at
      field :failure_count

      @@inclued = true
    end
  end

  def self.start
    self._include

    @@queue.async do
      jobs = self.all
      Log.info "[Nanoid::Sync][START] Processing #{jobs.count} jobs"
      jobs.each { |old_job| handle(old_job) }
    end
  end

  def self.process(klass, id)
    self._include

    instance = klass.find(id)
    self.notification(instance, 'start')
    job = self.new(:sync_class => instance.class.to_s,
                   :sync_id => instance.id,
                   :created_at => Time.now.utc,
                   :failure_count => 0)
    job.save if sync_up?(instance)
    handle(job)
  end

  def self.handle(job)
    self._include

    @@queue.async do
      instance = Object.qualified_const_get(job.sync_class).find(job.sync_id)
      if instance.updated_at > (instance._synced_at || Time.at(0))
        job.attempt(instance, :post_or_put)
      else
        job.attempt(instance, :get)
      end
    end
    nil
  end

  def self.sync_up?(instance)
    instance.updated_at > (instance._synced_at || Time.at(0))
  end

  def attempt(instance, method)
    case instance.send(method)
    when :success
      instance.update_attributes({:_synced_at => Time.now}, :skip_callbacks => true)
      self.destroy if self.persisted?
      self.class.notification(instance, 'success')
    when :failure
      if self.failure_count < Nanoid::Sync.max_failure_count
        self.failure_count += 1
        self.save
        self.class.notification(instance, 'retry')
      else
        Log.error "[Nanoid::Queue][CRITICAL] Job #{self.sync_class}:#{self.sync_id} exceeded failure threshold and has been removed"
        self.destroy if self.persisted?
        self.class.notification(instance, 'failure')
      end
    when :critical
      self.destroy if self.persisted?
      self.class.notification(instance, 'failure')
    end
  end

  private

  def self.notification(instance, type)
    NSNotificationCenter.defaultCenter.postNotificationName("nanoid:#{instance._type.downcase}:sync:#{type}", object: instance , userInfo: nil)
  end
end; end; end
