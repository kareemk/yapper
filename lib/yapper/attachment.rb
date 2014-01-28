motion_require 'document.rb'
motion_require 'sync.rb'

class Yapper::Attachment
  include Yapper::Document
  include Yapper::Sync

  sync

  class_attribute :attachments
  self.attachments = {}.with_indifferent_access

  field :name
  field :uid
  field :additional_fields

  def self.create(name, fields={})
    name = name.pluralize
    raise "#{name} attachment not a defined" unless attachments[name]
    fields.keys.each do |field|
      raise "Attachment field #{field} not defined for #{name}" unless attachments[name][:with].include?(field)
    end

    attachment = self.new
    attachment.name = name
    attachment.additional_fields = fields
    attachment.save

    attachment
  end

  def self.url(uid, size=nil)
    options = "[[\"f\",\"#{uid}\"]"
    options << ",[\"p\",\"thumb\", \"#{size}\"]" if size
    options << "]"
    path = [options].pack("m").tr("\n=",'')

    NSURL.URLWithString("#{Yapper::Sync.base_url}/#{path}.jpg")
  end

  def data
    self.attachments[name][:block].call(self)
  end

  def metadata
    self.additional_fields.merge(:id => self.id, :name => self.name).with_indifferent_access
  end
end
