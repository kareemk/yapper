module Yapper
  def self.transaction(&block)
    Yapper::DB.instance.execute(&block)
  end
end
