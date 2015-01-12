module Yapper::View
  extend MotionSupport::Concern

  module ClassMethods
    def view(version, &block)
      definition = ViewDefinition.new(name, version)
      definition.instance_eval(&block)
      self.db.view(definition)
    end

    def name
      self.to_s.underscore
    end

    def [](group, index)
      db.read do |txn|
        collection_ptr = Pointer.new(:object)
        key_ptr = Pointer.new(:object)
        if txn.ext("#{name}_VIEW").getKey(key_ptr,
                                          collection: collection_ptr,
                                          atIndex: index,
                                          inGroup: group)
          object_for_attrs(collection_ptr[0],
                           txn.objectForKey(key_ptr[0], inCollection: collection_ptr[0]))
        end
      end
    end

    def db
      Yapper::DB.instance
    end

    private

    def object_for_attrs(collection, attrs)
      Object.qualified_const_get(collection).new(attrs, :new => false, :pristine => true) rescue nil
    end
  end

  class ViewDefinition
    attr_reader :name
    attr_reader :version

    def initialize(name, version)
      @name = name
      @version = version

      self
    end

    def group(&block)
      @grouping_block = block
    end

    def sort(&block)
      @sorting_block = block
    end

    def sort_for(group, collection1, key1, attrs1, collection2, key2, attrs2)
      @sorting_block.call(group,
                          object_for_attrs(collection1, attrs1),
                          object_for_attrs(collection2, attrs2))
    end

    def group_for(collection, key, attrs)
      @grouping_block.call(object_for_attrs(collection, attrs))
    end

    private

    def object_for_attrs(collection, attrs)
      Object.qualified_const_get(collection).new(attrs, :new => false, :pristine => true) rescue nil
    end
  end
end
