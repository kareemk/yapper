module Nanoid::Sync
  extend MotionSupport::Concern

  class << self
    attr_accessor :base_url
    attr_accessor :access_token
    attr_accessor :max_failure_count
  end

  included do
    field :_remote_id
    field :_synced_at
    field :_sync_in_progress
    after_save :sync_if_auto

    unless self.ancestors.include?(Nanoid::Timestamps)
      include Nanoid::Timestamps
    end

    class << self
      attr_accessor :sync_to
      attr_accessor :sync_auto
    end
  end

  def self.configure(options)
    self.access_token      = options[:access_token]
    self.max_failure_count = options[:max_failure_count] || 5
  end

  include HTTP

  module ClassMethods
    def sync(options)
      self.sync_to = options[:to]
      self.sync_auto = options[:auto]
    end
  end

  def sync_as
    key = self.class.to_s.downcase.to_sym
    { key => self.attributes.reject{ |k,v| k == :id || k.to_s =~ /^_/ } }
  end

  def sync_if_auto
    if self.class.sync_auto
      sync
    end
  end

  def synced?
    !self._remote_id.nil?
  end

  def sync_in_progress?
    self._sync_in_progress
  end

  def sync
    Queue << self
  end
end
