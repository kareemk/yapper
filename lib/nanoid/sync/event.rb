module Nanoid::Sync
  module Event
    extend self

    def create(instance, type)
      delta = instance.sync_as

      params = {
        :event => {
          :model    => instance.model_name.capitalize,
          :model_id => instance.id,
          :type     => type,
          :delta    => delta
        }
      }

      request = http_client.multipartFormRequestWithMethod(
        'POST',
        path: Nanoid::Sync.sync_path,
        parameters: params,
        constructingBodyWithBlock: lambda { |form_data|
          instance.class.attachments.each do |name, block|
            attachment = instance.instance_eval(&block)
            form_data.appendPartWithFileData(attachment[:data],
                                             name: "event[delta][#{name}]",
                                             fileName: attachment[:file_name],
                                             mimeType: attachment[:mime_type])
          end
        })

      result = nil
      operation = AFJSONRequestOperation.alloc.initWithRequest(request)

      operation.start
      operation.waitUntilFinished

      if operation.response && operation.response.statusCode >= 200 && operation.response.statusCode < 300
        attrs = operation.responseJSON.dup
        Nanoid::Log.info "[Nanoid::Sync::Event][POST][#{instance.model_name}] #{attrs}"

        # XXX There must be a better way. Possibly calling Nanoid::Sync.sync
        # after every operation (i like this)
        new_attrs = {}
        attrs.each do |k, v|
          new_attrs[k] = v if instance.respond_to?(k) && instance.send(k).nil?
        end
        Nanoid::Sync.disabled { instance.reload.update_attributes(new_attrs) }

        result = :success
      else
        Nanoid::Log.warn "[Nanoid::Sync::Event][FAILURE][#{instance.model_name}] #{operation.error.userInfo}"
        result = :failure
      end

      result
    rescue Exception => e
      Nanoid::Log.error "[Nanoid::Sync][CRITICAL][#{instance.model_name}]  #{e.message}: #{e.backtrace.join('::')}"
      :critical
    end

    def get(&block)
      request = http_client.requestWithMethod(
        'GET',
        path: Nanoid::Sync.sync_path,
        parameters: { :since => last_event_id }
      )

      operation = AFJSONRequestOperation.alloc.initWithRequest(request)

      operation.start
      operation.waitUntilFinished

      if operation.response && operation.response.statusCode >= 200 && operation.response.statusCode < 300
        events = compact(operation.responseJSON)
        instances = []

        Nanoid::DB.default.batch do
          events.each do |event|
            Nanoid::Log.info "[Nanoid::Sync::Event][GET][#{event['type']}][#{event['model']}] #{event['delta']}"

            model = Object.qualified_const_get(event['model'])
            instance = nil
            if event['type'] == 'create'
              instance = model.new(event['delta'])
            else
              instance = model.find(event['model_id'])
            end

            if instance
              Nanoid::Document::Callbacks.disabled {
                Nanoid::Sync.disabled {instance.update_attributes(event['delta']) }
              }
              instances << instance
            else
              Nanoid::Log.error  "Model instance not found!. This is not good!"
            end
          end
        end
        update_last_event_id(events)
        block.call(instances)
      else
        Nanoid::Log.error "[Nanoid::Sync::Event][FAILURE] #{operation.error.localizedDescription}"
      end
    rescue Exception => e
      Nanoid::Log.error "[Nanoid::Sync::Event][FAILURE] #{e.message}: #{e.backtrace.join('::')}"
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
            create_event['delta'] = create_event['delta'].merge(event['delta'])
            compact_events[index] = create_event
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
  end
end
