module Nanoid::Sync
  module Event
    extend self

    def create(instance)
      delta = instance.sync_as
      type  = instance.synced? ? :update : :create

      params = {
        :event => {
          :model    => instance.model_name.capitalize,
          :model_id => instance.id,
          :type     => type,
          :delta    =>  delta
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
        instance.reload.update_attributes(new_attrs, :skip_callbacks => true)

        result = :success
      else
        $operation = operation
        Nanoid::Log.warn "[Nanoid::Sync::Event][FAILURE][#{instance.model_name}] #{operation.error.localizedDescription}"
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
        events = operation.responseJSON
        events.each do |event|
          Nanoid::Log.info "[Nanoid::Sync::Event][#{event['type']}][#{event['model']}] #{event}"

          model = Object.qualified_const_get(event['model'])
          instance = nil
          if event['type'] == 'create'
            instance = model.new(event['delta'])
          else
            instance = model.find(event['model_id'])
          end

          if instance.nil?
            update_last_event_id(event)
            raise "Model instance not found!. This is not good!"
          end

          attrs = event['delta'].dup

          instance.update_attributes(attrs, :skip_callbacks => true)

          block.call(instance)
          update_last_event_id(event)
        end
      else
        Nanoid::Log.error "[Nanoid::Sync::Event][FAILURE] #{operation.error.localizedDescription}"
      end
    rescue Exception => e
      Nanoid::Log.error "[Nanoid::Sync::Event][FAILURE] #{e.message}: #{e.backtrace.join('::')}"
    end

    def last_event_id
      user_defaults.objectForKey(last_event_id_key)
    end

    def update_last_event_id(event)
      Nanoid::Sync::Event.last_event_id = event['id'] || event['_id']
    end

    def last_event_id=(value)
      user_defaults.setObject(value, forKey: last_event_id_key)
      user_defaults.synchronize
    end

    private

    def user_defaults
      NSUserDefaults.standardUserDefaults
    end

    def last_event_id_key
      'nanoid:sync:last_event_id'
    end

    def http_client
      @http_client ||= begin
                         client = AFHTTPClient.alloc.initWithBaseURL(NSURL.URLWithString(Nanoid::Sync.base_url))
                         client.setParameterEncoding(AFJSONParameterEncoding)
                         client
                       end
      @http_client.setAuthorizationHeaderWithToken(Nanoid::Sync.access_token.call)
      # XXX Need to use UIDevice.currentDevice.identifierForVendor.UUIDString to
      # support iOS7 but this requires users to reinstall app
      @http_client.setDefaultHeader('DEVICEID', value: UIDevice.currentDevice.uniqueIdentifier)
    end
  end
end
