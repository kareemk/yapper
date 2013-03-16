module Nanoid::Document
  include Persistance
  include Selection

  def store
    Nanoid::DB.store
  end
end
