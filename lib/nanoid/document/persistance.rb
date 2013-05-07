module Nanoid
  module Document
    module Persistance
      extend MotionSupport::Concern

      included do
        attr_accessor :attributes

        class << self
          attr_accessor :fields
        end

        self.fields = {}
        field :id
      end

      module ClassMethods
        def create(*args)
          new(*args).tap { |doc| doc.save }
        end

        def field(name, options={})
          self.fields[name] = options

          define_method(name) do |*args, &block|
            self.attributes[name]
          end

          define_method("#{name}=".to_sym) do |*args, &block|
            self.set_attribute(name, args[0])
          end
        end

        def batch(every, &block)
          db.store.setSaveInterval(every)

          block.call

          error_ptr = Pointer.new(:id)
          db.store.saveStoreAndReturnError(error_ptr)
          db.store.setSaveInterval(1)
          raise_if_error(error_ptr)
        end
      end

      def initialize(attrs={}, options={})
        super

        @new_record = options[:new].nil? ? true : options[:new]
        assign_attributes(attrs, options)
        refresh_db_object

        self
      end

      def update_attributes(attrs, options={})
        self.assign_attributes(attrs, options)
        self.save(options)
      end

      def assign_attributes(attrs, options={})
        self.attributes ||= {}
        self.attributes = {} if options[:pristine]

        self.skip_callbacks = options[:skip_callbacks] || self.skip_callbacks || false

        attrs.each do |k,v|
          raise ArgumentError.new("Hashes not supported currently") if v.is_a?(Hash)
          __send__("#{k}=", v) if respond_to?(k)
        end
      end
      alias_method :attributes=, :assign_attributes

      def set_attribute(name, value)
        if self.class.fields[name][:type] == Time
          value = Time.parse(value) unless value.is_a?(Time)
        end
        self.attributes[name] = value
      end

      def reload
        reloaded = self.class.find(self.id)
        self.assign_attributes(reloaded.attributes, :prestine => true)
        self
      end

      def new_record?
        @new_record
      end

      def destroyed?
        !!@destroyed
      end

      def persisted?
        !new_record? && !destroyed?
      end

      def save(options={})
        run_callbacks 'save' do
          refresh_db_object

          error_ptr = Pointer.new(:id)
          db.store.addObject(@db_object, error: error_ptr)
          raise_if_error(error_ptr)
        end

        @new_record = false
        true
      end

      def destroy(options={})
        error_ptr = Pointer.new(:id)
        db.store.removeObject(@db_object, error: error_ptr)
        raise_if_error(error_ptr)
        @destroyed = true
      end

      private

      def refresh_db_object
        @db_object = NSFNanoObject.nanoObjectWithDictionary(attributes.merge(:_type => _type),
                                                                key: self.id)

        assign_attributes(attributes.merge(:id => @db_object.key))
      end
    end
  end
end
