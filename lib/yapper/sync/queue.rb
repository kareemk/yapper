motion_require '../document.rb'

module Yapper::Sync
  class Queue
    include Yapper::Document

    field :sync_class
    field :sync_id
    field :sync_changes
    field :sync_type
    field :created_at, :type => Time
    field :failure_count

    index :created_at

    @@mutex = Mutex.new
    @@notify_count = 0

    @@queue = NSOperationQueue.alloc.init
    @@queue.name = "#{NSBundle.mainBundle.bundleIdentifier}.yapper.sync"
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
      operation = NSBlockOperation.blockOperationWithBlock lambda {
        job_started
        jobs = self.where({}, :order => { :created_at => :asc })
        Yapper::Log.info "[Yapper::Sync][START] Processing #{jobs.count} jobs"
        jobs.each { |job| handle(job) }
        @@queue.setSuspended(!@@reachability.isReachable)
        job_ended
      }
      self.toggle_queue
      @@queue.addOperation(operation)
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
        job_started
        Yapper::Sync::Event.get.each { |instance| self.notification(instance, 'success') }
        job_ended
      }
      @@queue.addOperation(operation)

      true
    end

    def self.process(klass, id, type, changes)
      instance = klass.find(id)
      self.notification(instance, 'start')

      job = self.create(:sync_class    => instance.class.to_s,
                        :sync_id       => instance.id,
                        :sync_changes  => changes,
                        :sync_type     => type.to_s,
                        :created_at    => Time.now.utc,
                        :failure_count => 0)
      handle(job)
    end

    def self.handle(job)
      operation = NSBlockOperation.blockOperationWithBlock lambda {
        job_started
        instance = Object.qualified_const_get(job.sync_class).find(job.sync_id)
        instance.changes = job.sync_changes
        job.attempt(instance, job.sync_type)
        job_ended
      }
      self.toggle_queue

      @@queue.addOperation(operation)
      nil
    end

    def attempt(instance, type)
      case event(instance, type)
      when :success
        Yapper::Sync.disabled { instance.update_attributes(:_synced_at => Time.now) }
        self.destroy
        self.class.notification(instance, 'success')
      when :failure
        if self.failure_count < Yapper::Sync.max_failure_count
          sleep 2 ** (self.failure_count)
          self.failure_count += 1
          self.save
          attempt(instance, type)
          self.class.notification(instance, 'retry')
        else
          Yapper::Log.error "[Yapper::Queue][CRITICAL] Job #{self.sync_class}:#{self.sync_id} exceeded failure threshold and has been removed"
          self.destroy
          self.class.notification(instance, 'failure')
        end
      when :critical
        self.destroy
        self.class.notification(instance, 'failure')
      end
    end

    private

    def event(instance, type)
      if instance.is_a?(Yapper::Attachment)
        Yapper::Sync::Event.attach(instance)
      else
        Yapper::Sync::Event.create(instance, type)
      end
    end

    def self.toggle_queue
      was_paused = self.paused?
      @@queue.setSuspended(!@@reachability.isReachable)
      if was_paused != self.paused?
        NSNotificationCenter.defaultCenter.postNotificationName("yapper:sync:paused", object: true, userInfo: nil) if self.paused?
      end
    end

    def self.notification(instance, type)
      NSNotificationCenter.defaultCenter.postNotificationName("yapper:#{instance.model_name}:sync:#{type}", object: instance , userInfo: nil)
    end

    def self.job_started
      if @@queue.operationCount == 1
        @@job_started_at = Time.now
        NSNotificationCenter.defaultCenter.postNotificationName("yapper:sync:start", object: true , userInfo: nil)
      end
    end

    def self.job_ended
      if @@queue.operationCount == 1
        NSNotificationCenter.defaultCenter.postNotificationName("yapper:sync:end", object: Time.now - @@job_started_at , userInfo: nil)
      end
    end
  end
end
