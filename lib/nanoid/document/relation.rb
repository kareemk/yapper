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

            define_method(relation) do
              Object.qualified_const_get(relation.to_s.singularize.camelize).where("#{self._type.underscore}_id".to_sym => self.id)
            end

            define_method("#{relation}=") do |attrs|
              raise "You must pass an array of values" unless attrs.is_a?(Array)

              attrs.each do |attr|
                attr.merge!("#{self._type.underscore}" => self)
                Object.qualified_const_get(relation.singularize.to_s.camelize).create(attr)
              end
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
    end
  end
end
