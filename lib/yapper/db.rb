class Yapper::DB
  @@dbs   = {}
  @@queue = Dispatch::Queue.new("#{NSBundle.mainBundle.bundleIdentifier}.yapper.db#{@name}")

  def self.get(name)
    @@dbs[name] || begin
                     @@queue.sync do
                       @@dbs[name] ||= self.new(:name => name)
                     end
                     @@dbs[name]
                   end
  end

  def self.purge
    @@dbs.values.each(&:purge)
    true
  end

  def self.default
    get(:default)
  end

  attr_reader :indexes

  def initialize(options)
    @options = options
    @db = YapDatabase.alloc.initWithPath(document_path)
    @name = options[:name]
    @indexes = {}; @indexes_created = false

    self
  end

  def configure(&block)
    block.call(@db)
  end

  def execute(&block)
    create_indexes!

    exception = nil; result = nil
    unless self.txn
      txn_proc = proc do |_txn|
        self.txn = _txn
        begin
          result = block.call(txn)
        rescue Exception => e
          self.txn.rollback
          exception = e
        ensure
          self.txn = nil
        end
      end
      connection.readWriteWithBlock(txn_proc)

    else
      result = block.call(self.txn)
    end

    raise exception if exception
    result
  end

  def purge
    create_indexes!(true)
    execute { |txn| txn.removeAllObjectsInAllCollections }
  end

  def txn=(txn)
    Thread.current[:yapper_txn] = txn
  end

  def txn
    Thread.current[:yapper_txn]
  end

  def index(collection, field, type)
    @indexes[collection] ||= {}
    @indexes[collection][field] = { :type => type }
  end

  private

  def create_indexes!(force=false)
    return if @indexes_created && !force

    @@queue.sync do
      return if @indexes_created && !force

      @indexes.each do |collection, fields|
        setup = YapDatabaseSecondaryIndexSetup.alloc.init

        fields.each do |field, options|
          type = case options[:type].to_s
                 when 'String'
                   YapDatabaseSecondaryIndexTypeText
                 when 'Integer'
                   YapDatabaseSecondaryIndexTypeInteger
                 when 'Time'
                   YapDatabaseSecondaryIndexTypeInteger
                 else
                   raise "Invalid type #{type}"
                 end

          setup.addColumn(field, withType: type)
        end

        block = proc do |_dict, _collection, _key, _attrs|
          if indexes = @indexes[_collection]
            indexes.each do |field, options|
              field = field.to_s
              if _collection == collection
                value = case options[:type].to_s
                        when 'Time'
                          _attrs[field].to_i
                        else
                          _attrs[field]
                        end
                value = NSNull if value.nil?
                _dict.setObject(value, forKey: field)
              end
            end
          end
        end

        index_block = YapDatabaseSecondaryIndex.alloc.initWithSetup(setup, objectBlock: block)
        configure do |yap|
          yap.registerExtension(index_block, withName: "#{collection}_IDX")
        end
      end

      @indexes_created = true
    end
  end

  def connection
    @connection ||= @db.newConnection
  end

  def document_path
    NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] + "/#{@name}.db"
  end
end
