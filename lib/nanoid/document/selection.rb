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
          expressions = []

          criteria.each do |key, value|
            expression = NSFNanoExpression.expressionWithPredicate(NSFNanoPredicate.predicateWithColumn(NSFAttributeColumn, matching:NSFEqualTo, value:key.to_s))
            expression.addPredicate(NSFNanoPredicate.predicateWithColumn(NSFValueColumn, matching:NSFEqualTo, value:value.to_s), withOperator:NSFAnd)
            expressions << expression
          end

          results = self.db.execute do |store|
            search = NSFNanoSearch.searchWithStore(store)
            search.expressions = expressions

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
