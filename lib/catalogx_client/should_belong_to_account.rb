module CatalogXClient::ShouldBelongToAccount
  def self.extended(base)
    base.include(InstanceMethods)
  end

  def for_account(account_uuid)
    new(account_uuid)
  end

  module InstanceMethods
    attr_accessor :migration_status, :account_uuid

    def initialize(account_uuid)
      migration_status = CacheMetadata.cached_catalogx_migration_status_by_uuid(account_uuid)
      @account_uuid = account_uuid
      @migration_status = migration_status || 'default'
    end
  end
end
