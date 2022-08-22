module CatalogXClient
  class NotFoundError < StandardError; end
  class ResourceLockedError < StandardError; end
  class ConnectionError < StandardError; end
  class Error < StandardError; end

  class BaseClient
    def self.get_migration_status(account_uuid)
      migration_status = CacheMetadata.cached_catalogx_migration_status_by_uuid(account_uuid)
      migration_status || 'default'
    end

    def self.handle_request(path, http_verb, query_params: nil, body: nil, account_uuid: nil)
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
            request.url path
          end
        end
        handle_result(result)

      rescue Faraday::TimeoutError => ex
        $statsd.count(
          "catalogx_client.timeout.retry",
          1,
          tags: ["account_uuid:#{account_uuid}"]
        )
        retry_count += 1
        if retry_count <= CatalogXClient.max_retry
          sleep(rand(1..4))
          retry
        else
          raise
        end

      rescue Faraday::ConnectionFailed => ex
        $statsd.count(
          "catalogx_client.faraday_connection_error.retry",
          1,
          tags: ["account_uuid:#{account_uuid}"]
        )
        retry_count += 1
        if retry_count <= CatalogXClient.max_retry
          sleep(rand(1..4))
          retry
        else
          $statsd.count(
            "catalogx_client.faraday_connection_error.retry_exhausted",
            1,
            tags: ["account_uuid:#{account_uuid}"]
          )
          raise
        end

      rescue ResourceLockedError => ex
        $statsd.count(
          "catalogx_client.resource_locked.retry",
          1,
          tags: ["account_uuid:#{account_uuid}"]
        )
        retry_count += 1
        if retry_count <= CatalogXClient.max_retry
          sleep(rand(1..4))
          retry
        else
          $statsd.count(
            "catalogx_client.resource_locked.error",
            1,
            tags: ["account_uuid:#{account_uuid}"]
          )
          raise
        end

      rescue => ex
        $statsd.increment(
          "catalogx_client.handle_request.unhandled.exception",
          tags: [ "account_uuid:#{account_uuid}" ]
        )
        raise
      end
    end

    def self.handle_result(result)
      if result.success?
        Hashie::Mash.new(Oj.load(result.body))

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
