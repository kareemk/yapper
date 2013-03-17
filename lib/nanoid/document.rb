module Nanoid::Document
  extend MotionSupport::Concern

  included do
    extend  Nanoid::Error
  end

  include Nanoid::Error
  include Persistance
  include Selection
  include Callbacks
  include Sort

  module ClassMethods
    def db
      Nanoid::DB.default_db
    end

    def _type
      self.to_s
    end

  end

  def _type
    self.class._type
  end

  def db
    self.class.db
  end
end
