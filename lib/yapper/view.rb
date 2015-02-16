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

    def [](mapping_or_group, index)
      db.read do |txn|
        collection_ptr = Pointer.new(:object)
        key_ptr = Pointer.new(:object)

        found = if mapping_or_group.is_a?(YapDatabaseViewMappings)
                  txn.ext(extid).getKey(key_ptr,
                                        collection: collection_ptr,
                                        atIndexPath: index,
                                        withMappings: mapping_or_group)
                else
                  txn.ext(extid).getKey(key_ptr,
                                        collection: collection_ptr,
                                        atIndex: index,
                                        inGroup: mapping_or_group)
                end

        object_for_attrs(collection_ptr[0],
                         txn.objectForKey(key_ptr[0],
                                          inCollection: collection_ptr[0])) if found
      end
    end

    def count(group)
      db.read { |txn| txn.ext(extid).numberOfKeysInGroup(group) }
    end

    def watch(groups=[], &block)
      mapping = YapDatabaseViewMappings.alloc.initWithGroups(groups, view: extid)

      Yapper::Watch.add(mapping) do |notifications|
        section_changes = Pointer.new(:object)
        row_changes = Pointer.new(:object)
        db.read_connection.ext(extid).getSectionChanges(section_changes,
                                                        rowChanges: row_changes,
                                                        forNotifications: notifications,
                                                        withMappings: mapping)

        row_changes = row_changes[0]
        section_changes = section_changes[0]

        if row_changes.present? || section_changes.present?
          block.call(ChangeSet.new(row_changes, section_changes))
        end
      end
    end

    def db
      Yapper::DB.instance
    end

    def extid
      "#{name}_VIEW"
    end

    private

    def object_for_attrs(collection, attrs)
      Object.qualified_const_get(collection).new(attrs, :new => false, :pristine => true) rescue nil
    end
  end

  class ChangeSet
    attr_reader :rows
    attr_reader :sections

    def initialize(rows, sections)
      @rows     = rows.map { |row| RowChange.new(row) }
      @sections = sections.map { |section| SectionChange.new(section) }
    end

    class RowChange
      attr_reader :from
      attr_reader :to

      def initialize(change)
        @change = change
      end

      def from
        NSIndexPath.indexPathForRow(@change.originalIndex, inSection: @change.originalSection)
      end

      def to
        NSIndexPath.indexPathForRow(@change.finalIndex, inSection: @change.finalSection)
      end

      def type
        case @change.type
          when YapDatabaseViewChangeInsert then :insert
          when YapDatabaseViewChangeDelete then :delete
          when YapDatabaseViewChangeMove   then :move
          when YapDatabaseViewChangeUpdate then :update
          else raise "Unknown change type: #{@change.type}"
        end
      end
    end

    class SectionChange
      def initialize(change)
        @change = change
      end

      def type
        case @change.type
          when YapDatabaseViewChangeInsert then :insert
          when YapDatabaseViewChangeDelete then :delete
          else raise "Unknown change type: #{change.type}"
        end
      end

      def index
        @change.index
      end
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
