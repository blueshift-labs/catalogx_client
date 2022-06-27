module CatalogXClient
  class NotFoundError < StandardError; end
  class ResourceLockedError < StandardError; end
  class ConnectionError < StandardError; end
  class RetryError < StandardError; end
  class Error < StandardError; end

  class BaseClient

    SUCCESS_CODES = Set.new([200, 201, 204, 206]).freeze
    CONNECTION_ERROR_CODES = Set.new([408, 502, 503, 504]).freeze

    def handle_request(url, http_verb, query_params: nil, body: nil)
      retry_count = 0
      begin
        result = nil
        CatalogXClient.connections.with do |faraday_connection|
          result = faraday_connection.send(http_verb.to_s) do |request|
            request.headers['Content-Type'] = 'application/json'
            request.headers['Client-ID'] = CatalogXClient.client_id if CatalogXClient.client_id.present?
            request.params = query_params if query_params.present?
            request.body = body.to_json if body.present?
            request.options.timeout = CatalogXClient.timeout
            request.url(url)
          end
        end
        handle_result(result)

      rescue Faraday::TimeoutError => ex
        $statsd.count("catalogx_client.timeout.retry", 1)
        retry_count += 1
        if retry_count <= CatalogXClient.max_retry
          sleep(1)
          retry
        else
          raise RetryError.new("CatalogXClient max retry error: #{ex.message}")
        end

      rescue Faraday::ConnectionFailed => ex
        $statsd.count("catalogx_client.faraday_connection_error", 1)
        raise ConnectionError.new("CatalogXClient connection error: #{ex.message}")

      rescue ResourceLockedError => ex
        $statsd.count("catalogx_client.resource_locked.retry", 1)
        retry_count += 1
        if retry_count <= CatalogXClient.max_retry
          sleep(1)
          retry
        end

        $statsd.count("catalogx_client.resource_locked.error", 1)
        raise

      rescue
        $statsd.increment(
          "catalogx_client.handle_request.unhandled.exception",
          tags: [ "account_uuid:#{@account_uuid}" ]
        )
        raise
      end
    end

    def handle_result(result)
      if SUCCESS_CODES.include?(result.status)
        JSON.load(result.body)

      elsif result.status == 404
        raise NotFoundError.new("CatalogXClient resource not found error=#{result.body}")

      elsif result.status == 423
        raise ResourceLockedError.new("CatalogXClient resource locked error=#{result.body}")

      else
        raise Error.new("CatalogXClient error status=#{result.status}, body=#{result.body}")
      end
    end
  end
end
