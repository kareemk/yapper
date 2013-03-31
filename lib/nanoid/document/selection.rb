module Nanoid
  module Document
    module Selection
      extend MotionSupport::Concern

      module ClassMethods
        def find(id)
          search = NSFNanoSearch.searchWithStore(self.db.store)
          search.key = id

          error_ptr = Pointer.new(:id)
          result = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr).first
          raise_if_error(error_ptr)

          if result = result.try(:last)
            klass = Object.const_get(result.info.delete('_type'))
            klass.new(result.info, :new => false)
          end
        end

        def where(criteria)
          unless criteria.keys.length == 1
            raise Nanoid::Error::DB.new('where only supports single criteria at the moment')
          end
          criteria = criteria.first

          search = NSFNanoSearch.searchWithStore(self.db.store)
          search.attribute = criteria[0]
          search.match = NSFEqualTo
          search.value = criteria[1]

          error_ptr = Pointer.new(:id)
          results = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr)
          raise_if_error(error_ptr)

          results.map do |result|
            result = result[1]
            info = result.info.dup
            klass = Kernel.const_get(info.delete('_type'))
            klass.new(info, :new => false)
          end
        end
      end
    end
  end
end
