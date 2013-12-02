motion_require 'extensions'

module Nanoid::Document
  motion_require 'document/attachment'
  motion_require 'document/callbacks'
  motion_require 'document/persistance'
  motion_require 'document/relation'
  motion_require 'document/selection'
  motion_require 'document/sort'

  extend MotionSupport::Concern

  included do
    extend  Nanoid::Error
  end

  include Nanoid::Error
  include Persistance
  include Selection
  include Callbacks
  include Sort
  include Relation
  include Attachment

  module ClassMethods
    def db
      Nanoid::DB.default
    end

    def _type
      self.to_s
    end

    def model_name
      self.to_s.downcase
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
