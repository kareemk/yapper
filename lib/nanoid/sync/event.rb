module Nanoid::Sync
  module Event
    extend self

    def attach(attachment)
      params = {
        :attachment => attachment.additional_fields.merge(:id => attachment.id,
                                                          :name => attachment.name)
      }
      # XXX This is terrible. But a needed workaround for the iPhone 4.
      # Obviously temporary as this only works for ALAsset attachments
      @asset = attachment.data
      image = UIImage.imageWithCGImage(@asset.defaultRepresentation.fullResolutionImage,
                                       scale: 1.0,
                                       orientation: @asset.defaultRepresentation.orientation)
      request = http_client.multipartFormRequestWithMethod(
        'POST',
        path: Nanoid::Sync.attachment_path,
        parameters: params.as_json,
        constructingBodyWithBlock: lambda { |form_data|
            form_data.appendPartWithFileData(UIImageJPEGRepresentation(image, 0.8),
                                             name: "attachment[data]",
                                             fileName: @asset.defaultRepresentation.filename,
                                             mimeType: 'image/jpg')
        })

      if process(request)
        Nanoid::Log.info "[Nanoid::Sync::Event][ATTACHMENT][#{attachment.id}]"
        :success
      else
        :failure
      end
    end

    def create(instance, type)
      params =  {
        :event => {
          :model    => instance.sync.model,
          :model_id => instance.sync.id,
          :type     => type,
          :delta    => instance.sync.delta
        }
      }
      if instance._attachments
        params.merge!(:attachments => instance._attachments)
      end

      request = http_client.requestWithMethod(
        'POST',
        :path => Nanoid::Sync.data_path,
        :parameters => params.as_json)

      if operation = process(request)
        attrs = operation.responseJSON.deep_dup
        Nanoid::Log.info "[Nanoid::Sync::Event][POST][#{instance.model_name}] #{attrs}"

        new_attrs = {}
        attrs.each do |k, v|
          new_attrs[k] = v if instance.respond_to?(k) && instance.send(k).nil?
        end
        Nanoid::Sync.disabled { instance.reload.update_attributes(new_attrs) }
        :success
      else
        :failure
      end
    rescue Exception => e
      if e.is_a?(NSException)
        Nanoid::Log.error "[Nanoid::Sync][CRITICAL][#{instance.model_name}] #{e.reason}: #{e.callStackSymbols}"
      else
        Nanoid::Log.error "[Nanoid::Sync][CRITICAL][#{instance.model_name}] #{e.message}: #{e.backtrace.join('::')}"
      end
      :critical
    end

    def get
      request = http_client.requestWithMethod(
        'GET',
        path: Nanoid::Sync.data_path,
        parameters: { :since => last_event_id }
      )

      instances = []
      begin
        if operation = process(request)
          events = compact(operation.responseJSON)
          return events if events.empty?

          if events.first['model'] == 'User'
            instances << handle(events.shift)
          end

          Nanoid::DB.default.batch do
            events.each do |event|
              instances << handle(event)
            end
          end
          # XXX Doesn't seem to be updated on initial load
          update_last_event_id(events)
        end
      rescue Exception => e
        Nanoid::Log.error "[Nanoid::Sync::Event][FAILURE] #{e.message}: #{e.backtrace.join('::')}"
      end

      instances.compact
    end

    def last_event_id
      user_defaults.objectForKey(last_event_id_key)
    end

    def update_last_event_id(events)
      events.last.try { |event| Nanoid::Sync::Event.last_event_id = event['created_at'] }
    end

    def last_event_id=(value)
      user_defaults.setObject(value, forKey: last_event_id_key)
      user_defaults.synchronize
    end

    private

    def handle(event)
      Nanoid::Log.info "[Nanoid::Sync::Event][GET][#{event['type']}][#{event['model']}] #{event['delta']}"

      model = Object.qualified_const_get(event['model'])
      instance = nil
      if event['type'] == 'create'
        instance = model.new(event['delta']) # XXX shouldn't need to pass in delta
      else
        instance = model.find(event['model_id'])
      end

      if instance
        # XXX Return array of updates vs. overwriting entire object
        Nanoid::Sync.disabled { instance.update_attributes(event['delta']) }
      else
        Nanoid::Log.error  "Model instance not found!. This is not good!"
      end

      instance
    end

    def compact(events)
      event_lookup = {}; compact_events = []
      events.each_with_index do |event, i|
        case event['type']
        when 'create'
          event_lookup[event['model_id']] = compact_events.count
          compact_events << event
        when 'update'
          if index = event_lookup[event['model_id']]
            create_event = compact_events[index].dup
            create_event['delta'] = recursive_merge(create_event['delta'], event['delta'])
            compact_events[index] = create_event
          else
            compact_events << event
          end
        else
          raise "Only 'update' AND 'create' supported"
        end
      end
      compact_events
    end

    def user_defaults
      NSUserDefaults.standardUserDefaults
    end

    def last_event_id_key
      'nanoid:sync:last_event_id'
    end

    def uuid
      user_defaults.objectForKey(uuid_key) || begin
        uuid = UIDevice.currentDevice.identifierForVendor.UUIDString
        user_defaults.setObject(uuid, forKey: uuid_key)
        uuid
      end
    end

    def uuid_key
      'nanoid:sync:uuid'
    end

    def http_client
      @http_client ||= begin
                         client = AFHTTPClient.alloc.initWithBaseURL(NSURL.URLWithString(Nanoid::Sync.base_url))
                         client.setParameterEncoding(AFJSONParameterEncoding)
                         client
                       end
      @http_client.setAuthorizationHeaderWithToken(Nanoid::Sync.access_token.call)
      @http_client.setDefaultHeader('DEVICEID', value: uuid)
    end

    def process(request)
      operation = AFJSONRequestOperation.alloc.initWithRequest(request)

      operation.start
      operation.waitUntilFinished

      if operation.response && operation.response.statusCode >= 200 && operation.response.statusCode < 300
        operation
      else
        Nanoid::Log.error "[Nanoid::Sync::Event][FAILURE] #{operation.error.localizedDescription}"
        false
      end
    end

    def recursive_merge(h1, h2)
      return h1 unless h1.is_a?(Array) || h1.is_a?(Hash)

      result = h1.dup; h2 = h2.dup
      h2.each_pair do |k,v|
        tv = h1[k]
        if tv.is_a?(Hash) && v.is_a?(Hash)
          result[k] = recursive_merge(tv, v)
        elsif tv.is_a?(Array) && v.is_a?(Array)
          v = v.dup
          result[k] = tv.map do |_tv|
            if match = v.find { |_v| _tv.is_a?(Hash) && _v.is_a?(Hash) && _tv['id'] == _v['id'] }
              v.delete(match)
              recursive_merge(_tv, match)
            else
              _tv
            end
          end
          result[k] += v
        else
          result[k] = v
        end
      end
      result
    end
  end
end
