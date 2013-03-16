module Nanoid::Document
  extend MotionSupport::Concern

  include Persistance
  include Selection

  module ClassMethods
    def db
      Nanoid::DB.default_db
    end
  end

  def db
    self.class.db
  end
end
