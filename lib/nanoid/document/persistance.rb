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
          self.fields[name] = true

          define_method(name) do |*args, &block|
            self.attributes[name]
          end

          define_method("#{name}=".to_sym) do |*args, &block|
            self.attributes[name] = args[0]
          end
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
        assign_attributes(attrs, options={})
        save(options)
      end

      def assign_attributes(attrs, options={})
        self.attributes ||= {}
        self.attributes = {} if options[:pristine]

        attrs.each { |k,v| __send__("#{k}=", v) }
      end
      alias_method :attributes=, :assign_attributes

      def reload
        reloaded = self.class.find(self.id)
        self.assign_attributes(reloaded.attributes, :prestine => true)
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

          error = Pointer.new(:id)
          self.db.store.addObject(@db_object, error: error)
          raise Nanoid::Error::DB.new(error[0].description) if error[0]
        end

        @new_record = false
        true
      end

      private

      def refresh_db_object
        @db_object = NSFNanoObject.nanoObjectWithDictionary(attributes.merge(:_type => _type),
                                                                key: self.id)

        assign_attributes(attributes.merge(:id => @db_object.key), {})
      end

      def _type
        self.class.to_s
      end
    end
  end
end
