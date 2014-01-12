module Yapper::Document
  module Selection
    extend MotionSupport::Concern

    module ClassMethods
      def find(id)
        return nil if id.nil?

        attrs = db.execute { |txn| txn.objectForKey(id, inCollection: self._type) }

        attrs ? object_for_attrs(attrs) : nil
      end

      def all(options={})
        results = []
        each_result_proc = proc do |key, attrs, stop|
          results << object_for_attrs(attrs)
        end

        db.execute { |txn| txn.enumerateKeysAndObjectsInCollection(self._type, usingBlock: each_result_proc) }
        results
      end

      def where(criteria, options={})
        values = []; query_str = ''

        # Sort keys so that query string is always the same and is cached
        criteria.sort.each do |field, value|
          raise "#{field} is not indexed" if self.indexes[field].nil?

          query_str.blank? ? query_str = "WHERE " : query_str += " AND "
          query_str += "#{field} = ?"

          # XXX Casting should only happen if the type of the field allows for it
          value = case value.class.to_s
                  when 'Time'
                    value.to_i
                  else
                    value
                  end
          values << value
        end

        options.each do |option, params|
          case option
          when :order
            params.each do |sort_field, direction|
              if query_str.include?("ORDER by")
                query_str += ", "
              else
                query_str += " ORDER by "
              end
              query_str += "#{sort_field} #{direction.upcase}"
            end
          else
            raise "#{option} not a valid option on #where"
          end
        end

        query = YapDatabaseQuery.alloc.initWithQueryString(query_str, queryParameters: values)

        results = []
        each_result_proc = proc do |collection, key, attrs, stop|
          results << object_for_attrs(attrs)
        end

        db.execute { |txn| txn.ext("#{self._type}_IDX").enumerateKeysAndObjectsMatchingQuery(query, usingBlock: each_result_proc) }

        results
      end

      private

      def object_for_attrs(attrs)
        Object.qualified_const_get(self._type).new(attrs.deep_dup, :new => false, :pristine => true)
      end
    end
  end
end
