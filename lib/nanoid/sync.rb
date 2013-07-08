module Nanoid::Sync
  extend MotionSupport::Concern

  class << self
    attr_accessor :base_url
    attr_accessor :sync_path
    attr_accessor :access_token
    attr_accessor :max_failure_count
  end
  self.sync_path = '/api/data'

  def self.configure(options)
    self.access_token      = options[:access_token]
    self.max_failure_count = options[:max_failure_count] || 5
  end

  def self.sync
    Queue.sync
  end

  module ClassMethods
    def sync(options)
      field :_synced_at
      field :_syncing
      before_save :track_changes
      after_save  :sync_if_syncing

      unless self.ancestors.include?(Nanoid::Timestamps)
        include Nanoid::Timestamps
      end

      class << self
        attr_accessor :sync_to
        attr_accessor :sync_auto
      end
      self.sync_to = options[:to]
      self.sync_auto = options[:auto]
    end
  end

  def initialize(*args)
    super(*args)
    self._syncing = self.class.sync_auto if self.sync_configured? && @new_record
    self
  end

  def sync_configured?
    self.respond_to?(:_synced_at)
  end

  def sync_as(attrs=nil)
    attrs = attrs || self.changes.dup
    attrs.reject!{ |k,v| k.to_s =~ /^_/ }
    attrs
  end

  def synced?
    !self._synced_at.nil?
  end

  def sync_paused?
    Queue.paused?
  end

  def sync
    return false if self._syncing

    perform_sync(self.attributes.stringify_keys)
    self.update_attributes({:_syncing => true}, :skip_callbacks => true)

    true
  end

  private

  def perform_sync(changes)
    Queue.process(self.class, self.id, changes)
  end

  def sync_if_syncing
    if self._syncing
      perform_sync(@sync_changes)
    end
  end

  def track_changes
    @sync_changes = self.changes
  end
end
