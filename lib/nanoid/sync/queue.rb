module Nanoid; module Sync; class Queue
  @@included = false
  @@mutex = Mutex.new
  @@notify_count = 0
  @@queue = NSOperationQueue.alloc.init
  @@queue.name = "#{NSBundle.mainBundle.bundleIdentifier}.nanoid.sync"
  @@queue.MaxConcurrentOperationCount = 1

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
    @@reachability ||= begin
      reachability = Reachability.reachabilityWithHostname(Nanoid::Sync.base_url)
      reachability.reachableBlock   = lambda { |reachable| self.toggle_queue }
      reachability.unreachableBlock = lambda { |reachable| self.toggle_queue }
      reachability.startNotifier
      reachability
    end

    operation = NSBlockOperation.blockOperationWithBlock lambda {
      jobs = self.all
      Log.info "[Nanoid::Sync][START] Processing #{jobs.count} jobs"
      jobs.each { |old_job| handle(old_job) }
    }
    @@queue.addOperation(operation)
  end

  def self.paused?
    @@queue.isSuspended
  end

  def self.process(klass, id)
    self._include

    instance = klass.find(id)
    self.notification(instance, 'start')
    job = self.new(:sync_class => instance.class.to_s,
                   :sync_id => instance.id,
                   :created_at => Time.now.utc,
                   :failure_count => 0)
    job.save if sync_up?(instance) # Only persist update/delete/create
    handle(job)
  end

  def self.handle(job)
    self._include

    operation = NSBlockOperation.blockOperationWithBlock lambda {
      instance = Object.qualified_const_get(job.sync_class).find(job.sync_id)
      if self.sync_up?(instance)
        job.attempt(instance, :post_or_put)
      else
        job.attempt(instance, :get)
      end
    }
    self.toggle_queue
    @@queue.addOperation(operation)
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
        sleep self.failure_count * 0.2
        self.failure_count += 1
        self.save if self.persisted?
        attempt(instance, method)
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

  def self.toggle_queue
    was_paused = self.paused?
    @@queue.setSuspended(!@@reachability.isReachable)
    if was_paused != self.paused?
      NSNotificationCenter.defaultCenter.postNotificationName("nanoid:share:sync:paused", object: self.paused?, userInfo: nil)
    end
  end

  def self.notification(instance, type)
    NSNotificationCenter.defaultCenter.postNotificationName("nanoid:#{instance._type.downcase}:sync:#{type}", object: instance , userInfo: nil)
  end
end; end; end
