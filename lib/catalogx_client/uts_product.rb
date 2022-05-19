module CatalogXClient
  class UTSProduct < BaseClient
    extend UTSShouldBelongToAccount

    def upsert(product)
      begin
        if @account.is_migrating
          handle_request(
            "accounts/#{@account.uuid}/products",
            :post,
            query_params: {overwrite: true, migrating: true},
            body: product
          )
        end
      rescue
        $statsd.increment(
          "catalogx_client.uts.upsert.exception",
          tags: [ "account_uuid:#{@account.account_uuid}" ]
        )
        nil
      end
    end
  end
end
