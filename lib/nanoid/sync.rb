module Nanoid::Sync
  extend MotionSupport::Concern

  class << self
    attr_accessor :base_url
  end

  included do
    field :_remote_id
    field :_synced_at
    after_save :sync_if_auto

    unless self.ancestors.include?(Nanoid::Timestamps)
      include Nanoid::Timestamps
    end

    class << self
      attr_accessor :sync_to
      attr_accessor :sync_auto
    end
  end

  def self.max_failure_count
    5
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

  def sync
    Queue << self
  end
end
