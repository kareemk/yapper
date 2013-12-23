module Nanoid::Document
  module Persistance
    extend MotionSupport::Concern

    included do
      attr_accessor :attributes
      attr_accessor :changes
      attr_accessor :previous_changes

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
        name = name.to_sym
        self.fields[name] = options

        define_method(name) do |*args, &block|
          self.attributes[name]
        end

        define_method("#{name}=".to_sym) do |*args, &block|
          self.set_attribute(name, args[0])
        end
      end
    end

    def initialize(attrs={}, options={})
      super

      @new_record = options[:new].nil? ? true : options[:new]
      @changes = {}

      assign_attributes({:id => generate_id}, options) if @new_record

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

      if options[:pristine]
        self.attributes = {}
      end

      attrs.each do |k,v|
        if respond_to?("#{k}=")
          __send__("#{k}=", v) unless v.nil?
        else
          Log.warn "#{k} not defined on #{self.class}"
        end
      end

      if options[:pristine]
        self.changes = {}
      end
    end
    alias_method :attributes=, :assign_attributes

    def set_attribute(name, value)
      if self.class.fields[name][:type] == Time
        value = Time.parse(value) unless value.is_a?(Time)
      end
      # XXX This should not be set if the object was created from a
      # selection
      @changes[name.to_s] = value
      self.attributes[name] = value
    end

    def reload
      reloaded = self.class.find(self.id)
      self.assign_attributes(reloaded.attributes, :pristine => true)
      self
    end

    def new_record?
      @new_record
    end

    def was_new?
      @was_new
    end

    def destroyed?
      !!@destroyed
    end

    def persisted?
      !new_record? && !destroyed?
    end

    def save(options={})
      db.transaction do
        run_callbacks 'save' do
          refresh_db_object

          error_ptr = Pointer.new(:id)
          db.execute { |store| store.addObject(@db_object, error: error_ptr) }
          raise_if_error(error_ptr)

          @was_new = @new_record
          @new_record = false

          self.previous_changes = self.changes
          self.changes = {}
        end

        sync_changes if defined? sync_changes # XXX Use middleware pattern instead of this ugliness
        true
      end
    end

    def destroy(options={})
      error_ptr = Pointer.new(:id)
      db.execute { |store| store.removeObject(@db_object, error: error_ptr) }
      raise_if_error(error_ptr)
      @destroyed = true
    end

    private

    def generate_id
      BSON::ObjectId.generate
    end

    def refresh_db_object
      @db_object = NSFNanoObject.nanoObjectWithDictionary(stringify_keys(attributes.merge(:_type => _type)), key: self.id)
    end
  end

  private

  # TODO Use deep_stringify_keys once https://github.com/kareemk/motion-support is merged upstream
  def stringify_keys(hash)
    result = {}
    hash.each do |key, value|
      result[key.to_s] = if value.is_a?(Hash)
        stringify_keys(value)
      elsif value.is_a?(Array)
        value.map { |v| v.is_a?(Hash) ? stringify_keys(v) : v }
      else
       value
      end
    end
    result
  end
end
