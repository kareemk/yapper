module Yapper::Sync
  class Attachment
    attr_accessor :data
    attr_accessor :name
    attr_accessor :fileName
    attr_accessor :mimeType

    def initialize(params)
      params.each { |k,v| self.send("#{k}=", v) }
    end
  end
end
