# Dependencies
require 'faraday'
require 'faraday_middleware'
require 'ostruct'
require 'typhoeus'

# Modules
require "catalogx_client/version"
require "catalogx_client/config"
require "catalogx_client/should_belong_to_account"
require "catalogx_client/base_client"

module CatalogXClient
  class ConfigError < StandardError
    def initialize(errors); errors.join("\n") end
  end
  PATH_PREFIX = "/api/v2".freeze
  DEFAULT_MAX_RETRY = 3

  attr_accessor :client_id,
    :max_retry,
    :connections,
    :base_uri,
    :port,
    :pool_size,
    :timeout


  def self.configure(&blk)
    validate(&blk)

    @connections = ConnectionPool.new(size: @pool_size, timeout: @timeout) do
      connection = Faraday.new(url: @base_uri) do |conn|
        if LOG_FARADAY_RESPONSES
          conn.use Faraday::Response::Logger, APP_LOGGER || :logger
        end
        conn.adapter :typhoeus
      end
      connection.path_prefix = PATH_PREFIX
      connection
    end
  end

  def validate(&blk)
    config = CatalogXClient::Config.new
    yield(config)

    errors = []
    @host = options.host || errors.push("must configure a host")
    @port = options.port || 80
    @uri = URI("#{host}:#{port}")
    @max_retry = options.max_retry || DEFAULT_MAX_RETRY
    @pool_size = options.pool || 32
    @timeout = options.timeout || 10
    @client_id = options.client_id

    raise ConfigError.new(errors) unless errors.empty?
  end
end
