module Nanoid::Document
  extend MotionSupport::Concern

  included do
    extend  Nanoid::Error

    class << self
      attr_accessor :db_type
    end
  end

  include Nanoid::Error
  include Persistance
  include Selection
  include Callbacks
  include Sort

  module ClassMethods
    def store_in(type)
      self.db_type = type
    end

    def db
      Nanoid::DB.default_db(self.db_type)
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

  def model_name
    self.class.to_s.downcase
  end
end
