module Yapper::Document
  module Selection
    extend MotionSupport::Concern

    module ClassMethods
      def all(options={})
        Criteria.new(self, {}, options)
      end

      def where(criteria, options={})
        Criteria.new(self, criteria, options)
      end

      def asc(*fields)
        Criteria.new(self, {}, {}).sort(fields, :asc)
      end

      def desc(*fields)
        Criteria.new(self, {}, {}).sort(fields, :desc)
      end

      def count
        all.count
      end

      def search(query)
        return nil if query.nil?

        results = []
        each_result_proc = proc do |collection, id, attrs, stop|
          results << object_for_attrs(attrs)
        end

        db.execute { |txn| txn.ext("#{self._type}_SIDX").enumerateKeysAndObjectsMatching(query, usingBlock: each_result_proc) }

        results
      end

      def find(id)
        return nil if id.nil?

        attrs = db.execute { |txn| txn.objectForKey(id, inCollection: self._type) }

        attrs ? object_for_attrs(attrs) : nil
      end

      def when(id, &block)
        observer = nil
        observer_block = proc do |data|
          observer = nil
          NSNotificationCenter.defaultCenter.removeObserver(observer)
          block.call(data.object)
        end
        observer = NSNotificationCenter.
                     defaultCenter.
                     addObserverForName("yapper:#{self.model_name}:save",
                                        object: nil,
                                        queue: NSOperationQueue.mainQueue,
                                        usingBlock: observer_block) 
        if result = self.find(id)
          unless observer.nil?
            NSNotificationCenter.defaultCenter.removeObserver(observer)
            block.call(result) 
          end
        end
      end

      private

      def object_for_attrs(attrs)
        Object.qualified_const_get(self._type).new(attrs.deep_dup, :new => false, :pristine => true)
      end
    end
  end

  class Criteria
    def initialize(klass, criteria, options)
      @klass    = klass
      @criteria = criteria
      @options  = options
    end

    PointerType = (CGSize.type[/(f|d)/] == 'f') ? :uint : :ulong_long
    def count
      count_ptr = Pointer.new(PointerType)
      @klass.db.execute { |txn| txn.ext("#{@klass._type}_IDX").getNumberOfRows(count_ptr, matchingQuery: query) }
      count_ptr.value
    end

    def first
      asc(:id).limit(1).to_a.first
    end

    def last
      desc(:id).limit(1).to_a.first
    end

    def to_a
      results = []

      each_result_proc = proc do |collection, key, attrs, stop|
        results << object_for_attrs(attrs)
      end

      @klass.db.execute { |txn| txn.ext("#{@klass._type}_IDX").enumerateKeysAndObjectsMatchingQuery(query, usingBlock: each_result_proc) }

      results
    end

    def each(&block)
      to_a.each(&block)
    end

    def where(criteria)
      self.class.new(@klass, @criteria.merge(criteria), @options)
    end

    def limit(limit)
      self.class.new(@klass, @criteria, @options.merge(:limit => limit))
    end

    def sort(fields, direction)
      order = @options[:order].to_a + fields.map { |f| [f,direction] }
      self.class.new(@klass, @criteria, @options.merge(:order => order))
    end

    def asc(*fields)
      sort(fields, :asc)
    end

    def desc(*fields)
      sort(fields, :desc)
    end

    private

    def query
      values = []; query_str = ''

      # Sort keys so that query string is always the same and is cached
      @criteria.sort.each do |field, value|
        raise "#{field} is not indexed" if @klass.indexes[field].nil?

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

      @options.each do |option, params|
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
        when :limit
          query_str += " LIMIT #{params}"
        else
          raise "#{option} not a valid option on #where"
        end
      end

      YapDatabaseQuery.alloc.initWithQueryString(query_str, queryParameters: values)
    end

    def object_for_attrs(attrs)
      Object.qualified_const_get(@klass._type).new(attrs.deep_dup, :new => false, :pristine => true)
    end
  end
end
