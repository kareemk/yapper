module Nanoid::Document
  module Attachment
    extend MotionSupport::Concern

    included do
      field(:_attachments)
    end

    def attach(name, attachments)
      raise "Attachment #{name} not defined on #{self.class}" unless Nanoid::Attachment.attachments[name]

      self._attachments ||= {}
      self._attachments[name.to_s] = attachments.collect(&:id)
    end

    module ClassMethods
      def attach(name, options={}, &block)

        options[:class] = self
        options[:data]  = block

        field(name)
        Nanoid::Attachment.attachments[name] = options
      end
    end
  end
end
