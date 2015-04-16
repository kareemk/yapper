module Kernel
  def qualified_const_get(str)
    path = str.to_s.split('::')
    from_root = path[0].empty?
    if from_root
      from_root = []
      path = path[1..-1]
    else
      start_ns = ((Class === self)||(Module === self)) ? self : self.class
      from_root = start_ns.to_s.split('::')
    end
    until from_root.empty?
      begin
        return (from_root+path).inject(Object) { |ns,name| ns.const_get(name) }
      rescue NameError
        from_root.delete_at(-1)
      end
    end
    path.inject(Object) { |ns,name| ns.const_get(name) }
  end
end

class Time
  def self.parse(string)
    return nil if string.nil?

    unless time = NSDate.dateWithString(string)
      # XXX Try iso8601 date
      time = NSDate.dateWithString(string.gsub('T',' ').gsub('Z', ' +0000').gsub(/([-+]\d{2}:\d{2})/,' \1'))
    end
    time
  end

  def to_iso8601
    dateFormatter = NSDateFormatter.alloc.init
    locale = NSLocale.alloc.initWithLocaleIdentifier("en_US_POSIX")
    dateFormatter.setLocale(locale)
    dateFormatter.setDateFormat("yyyy-MM-dd'T'HH:mm:ssZZZZZ")

    dateFormatter.stringFromDate(self)
  end
end

class Hash
  def to_canonical
    self.keys.to_canonical + self.values.to_canonical
  end
end

class Array
  def to_canonical
    self.map { |v| v.class.to_s == 'Class' ? v.to_s : v}.map(&:to_canonical).sort.join
  end
end

class String
  def to_canonical
    self
  end
end

class Symbol
  def to_canonical
    to_s
  end
end

class Boolean; end

PointerIntType = (CGSize.type[/(f|d)/] == 'f') ? :uint : :ulong_long
