module Nanoid::Document::Persistance
  included do
    attr_accessor :attributes
    attr_accessor :fields

    self.fields = {}
    field :id
  end

  def initialize(attrs={}, options={})
    super

    @new_record = !options[:new]
    refresh_db_object
  end

  def assign_attributes(attrs, options={})
    attrs.each { |k,v| __send__("#{k}=", v) }
  end
  alias_method :attributes=, :assign_attributes

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
    error = Pointer.new(self)

    self.store.addObject(@db_object, error: error)
    raise Nanoid::Error::DB.new(error[0].description) if error[0]

    @new_record = false
    true
  end

  private

  def refresh_db_object
    @db_object = NSFNanoObject.new.nanoObjectWithDictionary(attributes.merge(:_type => _type),
                                                            key: self.id)

    assign_attributes(attrs.reverse_merge(:id => @db_object.key), options)
  end

  def _type
    self.class.to_s
  end

  module ClassMethods
    def create(*args)
      new(*args).tap { |doc| doc.save }
    end

    def field(name, options={})
      self.fields[name] = true

      define_method(name) do |*args, &block|
        self.attributes[name]
        refresh_db_object
      end

      define_method("#{name}=") do |*args, &block|
        self.attributes[name] = args[0]
        refresh_db_object
      end
    end
  end
end
