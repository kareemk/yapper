module Nanoid::Sync
  module HTTP
    def post_or_put
      data   = sync_as.select { |k,v| v.class == Nanoid::Sync::Attachment }
      params = sync_as.reject { |k,v| v.class == Nanoid::Sync::Attachment }
      method = 'POST'
      if self._remote_id # Update
        method = 'PUT'
      end

      request = http_client.multipartFormRequestWithMethod(
        method,
        path: path(method),
        parameters: params,
        constructingBodyWithBlock: lambda { |form_data|
          data.each do |name, attachment|
            form_data.appendPartWithFileData(UIImagePNGRepresentation(attachment.data),
                                             name: "#{self.model_name}[#{name}]",
                                             fileName: attachment.fileName,
                                             mimeType: attachment.mimeType)
          end
        })

      result = nil
      operation = AFJSONRequestOperation.alloc.initWithRequest(request)

      operation.start
      operation.waitUntilFinished

      # TODO If response 4xx then return :critical as this must be due to a bug
      if operation.response && operation.response.statusCode >= 200 && operation.response.statusCode < 300
        case method
        when 'POST'
          atts = operation.responseJSON.dup
          Log.info "[Nanoid::Sync][POST][#{self._type}] #{atts}"

          remote_id = atts.delete(:id) || atts.delete(:_id)
          raise "POST must return :id in payload" unless remote_id

          self.reload.update_attributes(atts.merge(:_remote_id => remote_id), :skip_callbacks => true)

        when 'PUT'
          Log.info "[Nanoid::Sync][PUT][#{self._type}] #{self._remote_id}"
        else
          raise "Unknown http method #{method}"
        end
        result = :success
      else
        Log.warn "[Nanoid::Sync][FAILURE][#{self._type}] #{operation.error.localizedDescription}"
        result = :failure
      end

      result
    rescue Exception => e
      Log.error "[Nanoid::Sync][CRITICAL][#{self._type}]  #{e.message}: #{e.backtrace.join('::')}"
      :critical
    end

    def get
      request = http_client.requestWithMethod(
        'GET',
        path: path('GET'),
        parameters: {}
      )

      result = nil
      operation = AFJSONRequestOperation.alloc.initWithRequest(request)

      operation.start
      operation.waitUntilFinished

      if operation.response && operation.response.statusCode >= 200 && operation.response.statusCode < 300
        atts = operation.responseJSON.dup
        Log.info "[Nanoid::Sync][GET][#{self._type}] #{atts}"

        atts.delete(:id)
        self.reload.update_attributes(atts, :skip_callbacks => true)

        result = :success
      else
        Log.warn "[Nanoid::Sync][FAILURE][#{self._type}] #{operation.error.localizedDescription}"
        result = :failure
      end

      result
    rescue Exception => e
      Log.error "[Nanoid::Sync][CRITICAL][#{self._type}] #{e.message}: #{e.backtrace.join('::')}"
      :critical
    end

    def path(method)
      path = self.class.sync_to.dup
      path.scan(/(:.[^\/]+)/).flatten.each do |interpolation|
        path.gsub!(interpolation, self.send(interpolation.gsub(':',''))._remote_id)
      end
      if ['PUT','GET'].include?(method)
        path += "/#{self._remote_id}"
      end
      path
    end

    private

    def http_client
      @http_client ||= begin
        client = AFHTTPClient.alloc.initWithBaseURL(NSURL.URLWithString(Nanoid::Sync.base_url))
        client.setParameterEncoding(AFJSONParameterEncoding)
        client
      end
    end
  end
end
