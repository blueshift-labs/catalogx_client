# Dependencies
require 'faraday'
require 'faraday_middleware'
require 'ostruct'
require 'typhoeus'

# Modules
require "catalogx_client/version"
require "catalogx_client/config"
require "catalogx_client/base_client"
require "catalogx_client/uts_should_belong_to_account"
require "catalogx_client/uts_product"
require "catalogx_client/bsft_should_belong_to_account"
require "catalogx_client/bsft_product"


module CatalogXClient
  PATH_PREFIX = "/api/v2".freeze
  DEFAULT_MAX_RETRY = 3

  class ConfigError < StandardError; end
  class << self
    def connections() @connections end
    def client_id() @client_id end
    def timeout() @timeout end
    def max_retry() @max_retry end

    def configure(&blk)
      self.validate(&blk)

      @connections = ConnectionPool.new(size: @pool_size, timeout: @timeout) do
        connection = Faraday.new(url: "http://#{@base_uri}") do |conn|
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

      host = config.host || raise(ConfigError.new("must provide host in config"))
      port = config.port || 80
      @base_uri = URI("#{host}:#{port}")
      @max_retry = config.max_retry || DEFAULT_MAX_RETRY
      @pool_size = config.pool || 32
      @timeout = config.timeout || 2
      @client_id = config.client_id
    end
  end
end
