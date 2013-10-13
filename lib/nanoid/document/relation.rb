module Nanoid::Document
  module Relation
    extend MotionSupport::Concern

    included do
      class << self
        attr_accessor :relations
      end

      self.relations = {}
      self.relations[:has_many] = []
      self.relations[:belongs_to] = []
    end

    module ClassMethods
      def has_many(*relations)
        relations.each do |relation|
          self.relations[:has_many] << relation unless self.relations[:has_many].include?(relation)

          define_method(relation) do
            Object.qualified_const_get(relation.to_s.singularize.camelize).where("#{self._type.underscore}_id".to_sym => self.id)
          end

          define_method("#{relation}=") do |attrs|
            raise "You must pass an array of attributes" unless attrs.is_a?(Array)

            instances = []
            attrs.each do |attr|
              attr = attr.merge("#{self._type.underscore}" => self)
              instance = Object.qualified_const_get(relation.singularize.to_s.camelize).create(attr)
              instances << instance.attributes
            end
            @changes.merge!(relation => instances)
          end

          define_method("#{relation.singularize}_ids=") do |ids|
            raise "You must pass an array of ids" unless ids.is_a?(Array)

            ids.each do |id|
              Object.qualified_const_get(relation.to_s.singularize.camelize).
                find(id).
                update_attributes({"#{self._type.underscore}" => self}, :skip_callbacks => true)
            end
            @changes.merge!("#{relation}_ids" => ids)
          end
        end
      end

      def belongs_to(relation)
        self.relations[:has_many] << relation unless self.relations[:has_many].include?(relation)
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
