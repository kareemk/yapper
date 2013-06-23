module Nanoid::Sync
  module Event
    extend self

    def create(instance)
      data  = instance.sync_as.select { |k,v| v.class == Nanoid::Sync::Attachment }
      delta = instance.sync_as.reject { |k,v| v.class == Nanoid::Sync::Attachment }

      params = {
        :event => {
          :model    => instance.model_name.capitalize,
          :model_id => instance._remote_id,
          :type     => instance.synced? ? :update : :create,
          :delta    =>  delta
        }
      }

      request = http_client.multipartFormRequestWithMethod(
        'POST',
        path: Nanoid::Sync.sync_path,
        parameters: params,
        constructingBodyWithBlock: lambda { |form_data|
          data.each do |name, attachment|
            form_data.appendPartWithFileData(attachment.data.call,
                                             name: "event[delta][#{name}]",
                                             fileName: attachment.fileName,
                                             mimeType: attachment.mimeType)
          end
        })

      result = nil
      operation = AFJSONRequestOperation.alloc.initWithRequest(request)

      operation.start
      operation.waitUntilFinished

      if operation.response && operation.response.statusCode >= 200 && operation.response.statusCode < 300
        attrs = operation.responseJSON.dup
        Nanoid::Log.info "[Nanoid::Sync::Event][POST][#{instance.model_name}] #{attrs}"

        remote_id = attrs.delete(:id) || attrs.delete(:_id)
        raise "POST must return :id in payload" unless remote_id

        if relation = instance.class.relations[:belongs_to]
          relation_id = "#{relation}_id".to_sym
          attrs[relation_id] = Object.qualified_const_get(relation.capitalize).find(attrs[relation_id]).id if attrs[relation_id]
        end

        instance.reload.update_attributes(attrs.merge(:_remote_id => remote_id), :skip_callbacks => true)
        result = :success
      else
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

          attrs = event['delta'].dup
          remote_id = attrs.delete(:id) || attrs.delete(:_id)
          attrs[:_remote_id] = remote_id if remote_id

          if relation = instance.class.relations[:belongs_to]
            relation_id = "#{relation}_id".to_sym
            attrs[relation_id] = Object.qualified_const_get(relation.capitalize).find(attrs[relation_id]).id if attrs[relation_id]
          end

          instance.update_attributes(attrs, :skip_callbacks => true)

          block.call(instance)
          Nanoid::Sync::Event.last_event_id = event['id'] || event['_id']
        end
      else
        Nanoid::Log.error "[Nanoid::Sync::Event] #{operation.error.localizedDescription}"
      end
    rescue Exception => e
      Nanoid::Log.error "[Nanoid::Sync::Event] #{e.message}: #{e.backtrace.join('::')}"
    end

    def last_event_id
      user_defaults.objectForKey(last_event_id_key)
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
      @http_client.setDefaultHeader('DEVICEID', value: UIDevice.currentDevice.uniqueIdentifier)
    end
  end
end
