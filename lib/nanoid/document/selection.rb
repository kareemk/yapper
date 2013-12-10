module Nanoid::Document
  module Selection
    extend MotionSupport::Concern

    module ClassMethods
      def find(id)
        return nil if id.nil?

        search do |search|
          search.key = id
        end.first
      end

      def all(options={})
        where({ :_type => self._type }, options)
      end

      def where(criteria, options={})
        expressions = []

        criteria.merge!(:_type => self._type)

        criteria.each do |key, value|
          expression = NSFNanoExpression.expressionWithPredicate(NSFNanoPredicate.predicateWithColumn(NSFAttributeColumn, matching:NSFEqualTo, value:key.to_s))
          expression.addPredicate(NSFNanoPredicate.predicateWithColumn(NSFValueColumn, matching:NSFEqualTo, value:value.to_s), withOperator:NSFAnd)
          expressions << expression
        end

        search(options) do |search|
          search.expressions = expressions
        end
      end

      private

      def search(options={}, &block)
        results = db.execute do |store|
          search = NSFNanoSearch.searchWithStore(store)
          search.limit  = options[:limit] if options[:limit]
          search.offset = options[:offset] if options[:offset]

          block.call(search)

          error_ptr = Pointer.new(:id)
          results = search.searchObjectsWithReturnType(NSFReturnObjects, error:error_ptr)
          raise_if_error(error_ptr)
          results
        end

        results.map do |result|
          result = result[1] if result.is_a?(Array)
          info = result.info.dup
          klass = Object.qualified_const_get(info.delete('_type'))
          klass.new(info, :new => false, :pristine => true)
        end
      end
    end
  end
end
