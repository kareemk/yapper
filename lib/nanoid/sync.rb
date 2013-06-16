module Nanoid::Sync
  extend MotionSupport::Concern

  class << self
    attr_accessor :base_url
    attr_accessor :sync_path
    attr_accessor :access_token
    attr_accessor :max_failure_count
  end
  self.sync_path = '/api/data'

  included do
    field :_remote_id
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
  end

  def self.configure(options)
    self.access_token      = options[:access_token]
    self.max_failure_count = options[:max_failure_count] || 5
  end

  def self.sync
    Queue.sync
  end

  module ClassMethods
    def sync(options)
      self.sync_to = options[:to]
      self.sync_auto = options[:auto]
    end

    def find(id)
      result = super(id)
      unless result
        result = where(:_remote_id => id).first
      end
      result
    end
  end

  def initialize(*args)
    super(*args)
    self._syncing = self.class.sync_auto if @new_record
    self
  end

  def sync_as
    attrs = self.changes.dup
    attrs.reject!{ |k,v| k == :id || k.to_s =~ /^_/ }
    if relation = self.class.relations[:belongs_to]
      relation_attr = "#{relation}_id"
      attrs[relation_attr] = self.send(relation)._remote_id if attrs[relation_attr.to_s]
    end
    attrs
  end

  def synced?
    !self._remote_id.nil?
  end

  def sync_paused?
    Queue.paused?
  end

  def sync
    return false if self._syncing

    perform_sync(self.attributes)
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
