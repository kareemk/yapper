motion_require 'extensions'

module Nanoid::Sync
  motion_require 'sync/data'
  motion_require 'sync/event'

  extend MotionSupport::Concern

  included do
    field :_synced_at

    unless self.ancestors.include?(Nanoid::Timestamps)
      include Nanoid::Timestamps
    end

    cattr_accessor :always

    class << self
      attr_accessor :attachments
    end
    self.attachments = {}
  end

  class << self
    attr_accessor :base_url
    attr_accessor :data_path
    attr_accessor :attachment_path
    attr_accessor :access_token
    attr_accessor :max_failure_count
  end
  self.data_path = '/api/data'
  self.attachment_path = '/api/attachment'

  def self.configure(options)
    self.access_token      = options[:access_token]
    self.max_failure_count = options[:max_failure_count] || 100
  end

  def self.sync
    Queue.sync
  end

  def self.disabled(&block)
    previous_value = Thread.current[:sync_disabled]
    Thread.current[:sync_disabled] = true
    yield
    Thread.current[:sync_disabled] = previous_value
  end

  module ClassMethods
    def sync(options={})
      self.always = options[:always] || []
    end

    def attachment(name, options, &block)
      raise ArgumentError unless options[:on] # XXX Use a consistent approach to checking hash params

      self.attachments[name] = block
      field(options[:on])
    end
  end

  def sync_as
    attrs = self.changes.dup
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
    @config ||= Config.new(self)
  end

  def sync_op
    self.was_new? ? :create : :update
  end

  private

  def perform_sync(changes)
    Queue.process(self.class, self.id, self.sync_op, changes) unless changes.empty?
  end

  def sync_changes
    perform_sync(self.previous_changes.merge(always_attributes)) unless Thread.current[:sync_disabled]
  end

  def always_attributes
    {}.tap do |attrs|
      self.always.each { |field| attrs[field] = self.send(field) }
    end
  end

  class Config
    def initialize(instance)
      @instance = instance
      @root = if parent
                instance.send(parent)
              else
                instance
              end
    end

    def id
      @root.id
    end

    def model
      @root.model_name.capitalize
    end

    def delta
      delta = @root.sync_as
      unless @root == @instance
        delta.merge!(@instance.model_name.pluralize => [@instance.sync_as.merge(:id => @instance.id)])
      end
      delta
    end

    private

    def parent
      @instance.class.relations[:belongs_to].find { |r| r.find { |k,v| v[:embedded] } }.try(:keys).try(:first)
    end
  end
end
