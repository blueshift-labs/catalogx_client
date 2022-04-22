module CatalogXClient::ShouldBelongToAccount
  def self.extended(base)
    base.include(InstanceMethods)
  end

  def for_account(account_uuid)
    new(account_uuid)
  end

  module InstanceMethods
    def initialize(account_uuid)
      @account_uuid = account_uuid
    end

    def account_uuid
      @account_uuid
    end

    def account_uuid=(account_uuid)
      @account_uuid=account_uuid
    end
  end
end
