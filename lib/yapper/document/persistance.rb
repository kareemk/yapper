module Yapper::Document
  module Persistance
    extend MotionSupport::Concern

    included do
      attr_accessor :attributes
      attr_accessor :changes
      attr_accessor :previous_changes

      class << self
        attr_accessor :fields
      end

      self.fields = {}.with_indifferent_access
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

        if options[:index]
          index(name, options[:type])
        end
      end

      def index(*index_fields)
        index_fields.each do |field|
          options = self.fields[field]; raise "#{self._type}:#{field} not defined" unless options
          type    = options[:type];    raise "#{self._type}:#{field} must define type as its indexed" if type.nil?

          db.index(self._type, field, type)
        end
      end

      def indexes
        db.indexes[self._type]
      end
    end

    def initialize(attrs={}, options={})
      super

      @new_record = options[:new].nil? ? true : options[:new]
      @changes = {}
      @queued_saves = []

      assign_attributes({:id => generate_id}, options) if @new_record
      assign_attributes(attrs, options)

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
      db.execute do |txn|
        @queued_saves.each { |queued, queued_options| queued.save(queued_options) }

        run_callbacks 'save' do
          txn.setObject(stringify_keys(attributes), forKey: self.id, inCollection: _type)

          @was_new = @new_record
          @new_record = false
          @queued_saves = []

          self.previous_changes = self.changes
          self.changes = {}
        end

        unless options[:embedded]
          # XXX Use middleware pattern instead of this ugliness
          sync_changes if defined? sync_changes
        end

        db.on_commit { self.notify('save') }
      end

      true
    end

    def destroy(options={})
      db.execute { |txn| txn.removeObjectForKey(self.id, inCollection: _type) }
      @destroyed = true
    end

    private

    def generate_id
      BSON::ObjectId.generate
    end
  end

  def notify(operation)
    NSNotificationCenter.defaultCenter.postNotificationName("yapper:#{self.model_name}:#{operation}", object: self , userInfo: nil)
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
