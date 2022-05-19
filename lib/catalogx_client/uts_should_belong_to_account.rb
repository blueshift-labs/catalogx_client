module CatalogXClient::UTSShouldBelongToAccount
  def self.extended(base)
    base.include(InstanceMethods)
  end

  def for_account(account_uuid)
    new(account_uuid)
  end

  module InstanceMethods
    attr_accessor :account

    def initialize(account_uuid)
      account = AccountByKey.cached_get_account_by_uuid(account_uuid)
      if account
        is_migrating = account.try(:is_catalogx_migrating)
        account.is_migrating = !!is_migrating
        @account = account
      else
        @account = AccountByKey.new
        @account.is_catalogx_migrating = false
        @account.account_uuid = account_uuid
      end
    end
  end
end
