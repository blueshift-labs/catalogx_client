module CatalogXClient::BSFTShouldBelongToAccount
  def self.extended(base)
    base.include(InstanceMethods)
  end

  def for_account(account_uuid)
    new(account_uuid)
  end

  module InstanceMethods
    attr_accessor :account

    def initialize(account_uuid)
      account = CacheMetadata.cached_account_by_uuid(account_uuid)
      if account
        @account = account
      else
        @account.catalogx_migration_status = 'default'
        @account.account_uuid = account_uuid
      end
    end
  end
end
