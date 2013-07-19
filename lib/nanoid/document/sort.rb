module Nanoid::Document
  module Sort
    extend MotionSupport::Concern

    module ClassMethods
      def asc(field)
        sort(field, true)
      end

      def desc(field)
        sort(field, false)
      end

      private

      def sort(field, ascending)
        results = self.db.execute do |store|
          search = NSFNanoSearch.searchWithStore(store)
          search.attribute = '_type'
          search.match = NSFEqualTo
          search.value = self._type

          search.sort = [NSFNanoSortDescriptor.alloc.initWithAttribute(field.to_s, ascending:ascending)]

          error_ptr = Pointer.new(:id)
          results = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr)
          raise_if_error(error_ptr)
          results
        end

        results.map do |result|
          info = result.info.dup
          klass = Kernel.qualified_const_get(info.delete('_type'))
          klass.new(info, :new => false, :pristine => true)
        end
      end
    end
  end
end
