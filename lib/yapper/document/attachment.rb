module Yapper::Document
  module Attachment
    extend MotionSupport::Concern

    included do
      field(:_attachments)
    end

    def attach(name, attachments)
      raise "Attachment #{name} not defined on #{self.class}" unless Yapper::Attachment.attachments[name]

      self._attachments ||= {}
      self._attachments[name.to_s] = attachments.collect(&:id)
    end

    module ClassMethods
      def attach(name, options={}, &block)

        options[:class] = self

        field(name)
        Yapper::Attachment.attachments[name] = options
      end
    end
  end
end
