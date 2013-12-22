motion_require 'document.rb'
motion_require 'sync.rb'

class Nanoid::Attachment
  include Nanoid::Document
  include Nanoid::Sync

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

    NSURL.URLWithString("#{Nanoid::Sync.base_url}/#{path}.jpg")
  end

  def data
    attachments[name][:class].attachment(self.additional_fields.with_indifferent_access)
  end
end
