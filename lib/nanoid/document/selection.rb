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
      end
    end
  end
end
