module CatalogXClient

  class MultipleUsersError < StandardError; end
  class BadRequestError < StandardError; end
  class NotFoundError < StandardError; end
  class ResourceConflictError < StandardError; end
  class ForgottenUserAccessedError < StandardError; end
  class ResourceLockedError < StandardError; end
  class UserBloatedIndicesError < StandardError; end
  class ConnectionError < StandardError; end
  class Error < StandardError; end

  class BaseClient

    SUCCESS_CODES = Set.new([200, 201, 204, 206]).freeze
    CONNECTION_ERROR_CODES = Set.new([408, 502, 503, 504]).freeze

    def handle_request(url, http_verb, params: nil, body: nil)
      retry_count = 0
      begin
        result = nil
        CatalogXClient.connections.with do |faraday_connection|
          result = faraday_connection.send(http_verb.to_s) do |request|
            request.url(url)
            request.headers['Content-Type'] = 'application/json'
            request.headers['Client-ID'] = CatalogXClient.client_id if CatalogXClient.client_id.present?

            request.params = params if params.present?
            request.body = body.to_json if body.present?
            request.options[:timeout] = 600
          end
        end
        handle_result(result)
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => ex
        $statsd.count("catalogx_client.faraday_connection_error", 1)
        raise ConnectionError.new("CatalogXClient connection error: #{ex.message}")
      rescue ResourceLockedError => ex
        $statsd.count("catalogx_client.resource_locked.count", 1)
        retry_count += 1
        if retry_count <= CatalogXClient.max_retry
          sleep(3)
          retry
        end

        $statsd.count("catalogx_client.resource_locked.error", 1)
        raise
      end
    end

    def handle_result(result)
      $statsd.count("catalogx_client.response.count", 1, tags: ["status:#{result.status}"])

      if SUCCESS_CODES.include?(result.status)
        json_result = JSON.load(result.body)
        if json_result.is_a?(Array)
          json_result.inject([]) { |arr, r| arr << Hashie::Mash.new(r) }
        else
          Hashie::Mash.new(json_result)
        end
      elsif result.status == 300
        raise MultipleUsersError.new(result.body)
      elsif result.status == 400
        raise BadRequestError.new(result.body)
      elsif result.status == 404
        raise NotFoundError.new("CatalogXClient resource not found error"\
          "=#{result.body}")
      elsif result.status == 409
        raise ResourceConflictError.new("CatalogXClient resource conflict error"\
          "=#{result.body}")
      elsif result.status == 410
        raise ForgottenUserAccessedError.new("CatalogXClient forgotten user accessed error"\
          "=#{result.body}")
      elsif result.status == 423
        raise ResourceLockedError.new("CatalogXClient resource locked error"\
          "=#{result.body}")
      elsif result.status == 430
        raise UserBloatedIndicesError.new("CatalogXClient bloated indices error"\
          "=#{result.body}")
      elsif CONNECTION_ERROR_CODES.include?(result.status)
        raise ConnectionError.new("CatalogXClient connection status=#{result.status}"\
        " #{result.body}")
      else
        raise Error.new("CatalogXClient error status=#{result.status} #{result.body}")
      end
    end
  end
end
