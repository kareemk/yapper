motion_require '../document.rb'

module Nanoid::Sync
  class Queue
    include Nanoid::Document

    field :sync_class
    field :sync_id
    field :sync_changes
    field :created_at
    field :failure_count

    @@mutex = Mutex.new
    @@notify_count = 0

    @@queue = NSOperationQueue.alloc.init
    @@queue.name = "#{NSBundle.mainBundle.bundleIdentifier}.nanoid.sync"
    @@queue.MaxConcurrentOperationCount = 1
    @@queue.setSuspended(true)

    @@reachability ||= begin
                         reachability = Reachability.reachabilityForInternetConnection
                         reachability.reachableBlock   = lambda { |reachable| self.toggle_queue }
                         reachability.unreachableBlock = lambda { |reachable| self.toggle_queue }
                         reachability.reachableOnWWAN = true
                         reachability.startNotifier
                         reachability
                       end

    NSNotificationCenter.defaultCenter.addObserver(self,
                                                   selector: 'onBackground',
                                                   name: UIApplicationDidEnterBackgroundNotification,
                                                   object: nil)


    def self.start
      Dispatch.once do
        jobs = self.asc(:created_at)
        Nanoid::Log.info "[Nanoid::Sync][START] Processing #{jobs.count} jobs"
        jobs.each { |job| handle(job) }
        @@queue.setSuspended(!@@reachability.isReachable)
      end
    end

    def self.onBackground
      @@background_task = UIApplication.sharedApplication.beginBackgroundTaskWithExpirationHandler(nil)
      operation = NSBlockOperation.blockOperationWithBlock lambda {
        UIApplication.sharedApplication.endBackgroundTask(@@background_task) unless @@background_task == UIBackgroundTaskInvalid
        @@background_task = UIBackgroundTaskInvalid
      }
      @@queue.addOperation(operation)
    end

    def self.paused?
      @@queue.isSuspended
    end

    def self.sync
      return false if self.paused?

      operation = NSBlockOperation.blockOperationWithBlock lambda {
        Nanoid::Sync::Event.get { |instance, status| self.notification(instance, 'success') }
      }
      @@queue.addOperation(operation)

      true
    end

    def self.process(klass, id, changes)
      instance = klass.find(id)
      self.notification(instance, 'start')

      job = self.create(:sync_class    => instance.class.to_s,
                        :sync_id       => instance.id,
                        :sync_changes  => changes,
                        :created_at    => Time.now.utc,
                        :failure_count => 0)
      handle(job)
    end

    def self.handle(job)
      operation = NSBlockOperation.blockOperationWithBlock lambda {
        instance = Object.qualified_const_get(job.sync_class).find(job.sync_id)
        instance.changes = job.sync_changes
        job.attempt(instance)
      }
      self.toggle_queue
      @@queue.addOperation(operation)
      nil
    end

    def attempt(instance)
      case Nanoid::Sync::Event.create(instance)
      when :success
        instance.update_attributes({:_synced_at => Time.now}, :skip_callbacks => true)
        self.destroy
        self.class.notification(instance, 'success')
      when :failure
        if self.failure_count < Nanoid::Sync.max_failure_count
          sleep 2 ** (self.failure_count)
          self.failure_count += 1
          self.save
          attempt(instance)
          self.class.notification(instance, 'retry')
        else
          Nanoid::Log.error "[Nanoid::Queue][CRITICAL] Job #{self.sync_class}:#{self.sync_id} exceeded failure threshold and has been removed"
          self.destroy
          self.class.notification(instance, 'failure')
          # TODO Set _syncing to false
        end
      when :critical
        self.destroy
        self.class.notification(instance, 'failure')
      end
    end

    private

    def self.toggle_queue
      was_paused = self.paused?
      @@queue.setSuspended(!@@reachability.isReachable)
      if was_paused != self.paused?
        NSNotificationCenter.defaultCenter.postNotificationName("nanoid:sync:paused", object: true, userInfo: nil)
      end
    end

    def self.notification(instance, type)
      NSNotificationCenter.defaultCenter.postNotificationName("nanoid:#{instance.model_name}:sync:#{type}", object: instance , userInfo: nil)
    end
  end
end
