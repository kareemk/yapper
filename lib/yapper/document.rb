motion_require 'extensions'
motion_require 'db'

module Yapper::Document
  motion_require 'document/callbacks'
  motion_require 'document/persistence'
  motion_require 'document/relation'
  motion_require 'document/selection'

  extend MotionSupport::Concern

  include Persistence
  include Selection
  include Callbacks
  include Relation

  included do
    field :id, :type => String
    index(:id)
  end

  module ClassMethods
    def db
      Yapper::DB.instance
    end

    def _type
      self.to_s
    end

    def model_name
      self.to_s.downcase
    end

    def watch(&block)
      Yapper::Watch.add do |notifications|
        block.call if db.read_connection.hasChangeForCollection(self._type,
                                                                inNotifications: notifications)
      end
    end
  end

  def watch(&block)
    Yapper::Watch.add do |notifications|
      block.call if db.read_connection.hasChangeForKey(self.id,
                                                       inCollection: self._type,
                                                       inNotifications: notifications)
    end
  end

  def _type
    self.class._type
  end

  def db
    self.class.db
  end

  def model_name
    self.class.model_name
  end

  # TODO Add specs
  def ==(other)
    self.id == other.try(:id)
  end
  alias :eql? :==

  def hash
    self.id.hash
  end
end
