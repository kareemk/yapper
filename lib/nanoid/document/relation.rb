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

          define_method("#{relation}=") do |docs|
            raise "You must pass an array of objects or attributes" unless docs.is_a?(Array)
            raise "All elements in the array must be of the same type" unless docs.all? { |doc| doc.is_a?(docs.first.class) }

            changes = {}
            docs.each do |doc|
              # XXX Add skip_sync vs. skip_callbacks option as callbacks
              # probably still should be fired in most circumstances
              if doc.is_a?(Nanoid::Document)
                if doc.persisted?
                  doc.update_attributes({"#{self._type.underscore}" => self}, :skip_callbacks => true)
                  changes["#{relation.singularize}_ids"] ||= []
                  changes["#{relation.singularize}_ids"] << doc.id
                else
                  doc.assign_attributes({"#{self._type.underscore}" => self}, :skip_callbacks => true)
                  doc.save
                  changes[relation] ||= []
                  changes[relation] << doc.attributes
                end
              elsif doc.is_a?(Hash)
                attr = doc.merge("#{self._type.underscore}" => self)
                instance = Object.qualified_const_get(relation.singularize.to_s.camelize).create(attr, :skip_callbacks => true)
                changes[relation] ||= []
                changes[relation] << instance.attributes
              else
                raise "Must pass either attributes or an object"
              end
            end
            @changes.merge!(changes)
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
