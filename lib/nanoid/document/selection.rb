module Nanoid
  module Document
    module Selection
      extend MotionSupport::Concern

      module ClassMethods
        def find(id)
          return nil if id.nil?

          result = db.execute do |store|
            search = NSFNanoSearch.searchWithStore(store)
            search.key = id

            error_ptr = Pointer.new(:id)
            result = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr).first
            raise_if_error(error_ptr)
            result
          end

          if result = result.try(:last)
            info = result.info.dup
            klass = Object.qualified_const_get(info.delete('_type'))
            klass.new(info, :new => false)
          end
        end

        def where(criteria)
          unless criteria.keys.length == 1
            raise Nanoid::Error::DB.new('where only supports single criteria at the moment')
          end
          criteria = criteria.first

          results = self.db.execute do |store|
            search = NSFNanoSearch.searchWithStore(store)
            search.attribute = criteria[0]
            search.match = NSFEqualTo
            search.value = criteria[1]

            error_ptr = Pointer.new(:id)
            results = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr)
            raise_if_error(error_ptr)
            results
          end

          results.map do |result|
            result = result[1]
            info = result.info.dup
            klass = Object.qualified_const_get(info.delete('_type'))
            klass.new(info, :new => false)
          end
        end

        def all
          results = db.execute do |store|
            search = NSFNanoSearch.searchWithStore(store)
            search.attribute = '_type'
            search.match = NSFEqualTo
            search.value = self._type

            error_ptr = Pointer.new(:id)
            results = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr)
            raise_if_error(error_ptr)
            results
          end

          results.map do |result|
            result = result[1]
            info = result.info.dup
            klass = Object.qualified_const_get(info.delete('_type'))
            klass.new(info, :new => false)
          end
        end
      end
    end
  end
end
