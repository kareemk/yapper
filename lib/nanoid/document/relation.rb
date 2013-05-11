module Nanoid
  module Document
    module Relation
      extend MotionSupport::Concern

      included do
        class << self
          attr_accessor :relations
        end

        self.relations = {}
        self.relations[:has_many] = []
        self.relations[:belongs_to] = nil
      end

      module ClassMethods
        def has_many(*relations)
          relations.each do |relation|
            self.relations[:has_many] << relation unless self.relations.include?(relation)
            self.field("#{relation}_ids")

            define_method(relation) do
              self.send("#{relation}_ids").map { |id| Object.qualified_const_get(relation.to_s.singularize.camelize).find(id) } if self.send("#{relation}_ids")
            end
          end
        end

        def belongs_to(relation)
          raise "Can only belong_to one parent" if self.relations[:belongs_to]
          self.relations[:belongs_to] = relation
          self.field("#{relation}_id")

          define_method(relation) do
            Object.qualified_const_get(relation.to_s.camelize).find(self.send("#{relation}_id"))
          end

          define_method("#{relation}=") do |parent|
            self.send("#{relation}_id=", parent.id)
          end
        end
      end

      def update_associations(operation)
        if self.class.relations[:belongs_to] 
          inverse = self.send(self.class.relations[:belongs_to])
          inverse_ids_field = "#{self._type.underscore.pluralize}_ids".to_sym
          inverse_ids = inverse.send(inverse_ids_field)
          inverse_ids ||= []
          case operation
          when :created
            inverse_ids << self.id unless inverse_ids.include?(self.id)
          when :destroyed
            inverse_ids.delete(self.id)
          end

          attrs = {}
          attrs[inverse_ids_field] = inverse_ids
          inverse.update_attributes(attrs, :skip_callbacks => true)
        end
      end
    end
  end
end
