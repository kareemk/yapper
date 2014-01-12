class BSON
  class ObjectId
    @@machine_id = NSData.MD5HexDigest(UIDevice.currentDevice.identifierForVendor.UUIDString.dataUsingEncoding(NSUTF8StringEncoding)).unpack("N")[0]

    @@mutex = Mutex.new
    @@counter = 0

    def self.generate
      @@mutex.lock
      begin
        counter = @@counter = (@@counter + 1) % 0xFFFFFF
      ensure
        @@mutex.unlock rescue nil
      end

      process_thread_id = "#{Process.pid}#{Thread.current.object_id}".hash % 0xFFFF
      [Time.new.to_i, @@machine_id, process_thread_id, counter << 8].pack("N NX lXX NX").unpack("H*")[0]
    end
  end
end
