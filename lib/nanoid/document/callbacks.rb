module Nanoid::Document
  module Callbacks
    extend MotionSupport::Concern

    included do
      class << self
        attr_accessor :before_save_callbacks
        attr_accessor :after_save_callbacks
      end

      self.before_save_callbacks = []
      self.after_save_callbacks  = []
    end

    def self.postpone_callbacks(&block)
      Thread.current[:postponed_callbacks] = []

      block.call

      Thread.current[:postponed_callbacks].each(&:call)
      Thread.current[:postponed_callbacks] = nil
    end

    def self.disabled(&block)
      previous_value = Thread.current[:disabled_callbacks]
      Thread.current[:disabled_callbacks] = true

      block.call

      Thread.current[:disabled_callbacks] = previous_value
    end

    def self.disabled?
      !!Thread.current[:disabled_callbacks]
    end

    def self.postpone_callback(&block)
      Thread.current[:postponed_callbacks] << Proc.new(block)
    end

    def self.postponed_callbacks
      Thread.current[:postponed_callbacks]
    end

    module ClassMethods
      def before_save(method)
        self.before_save_callbacks << method
      end

      def after_save(method)
        self.after_save_callbacks << method
      end
    end

    def run_callback(hook, operation)
      self.class.send("#{hook}_#{operation}_callbacks").each do |method|
        self.send(method)
      end
    end

    def run_callbacks(operation, &block)
      return yield if Nanoid::Document::Callbacks.disabled?

      if run_callback('before', operation)
        block.call
      end

      callback_proc = Proc.new do
        run_callback('after', operation)
        notify_callback(operation)
      end

      if Nanoid::Document::Callbacks.postponed_callbacks
        Nanoid::Document::Callbacks.postpone_callback(&callback_proc)
      else
        callback_proc.call
      end
    end

    private

    def notify_callback(operation)
      NSNotificationCenter.defaultCenter.postNotificationName("nanoid:#{self.model_name}:#{operation}", object: self , userInfo: nil)
    end
  end
end
