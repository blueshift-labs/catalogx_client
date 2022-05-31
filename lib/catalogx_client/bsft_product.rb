module CatalogXClient
  class BSFTProduct < BaseClient
    extend BSFTShouldBelongToAccount

    MIGRATION_STATE = {
      default: 'default',
      migrated: 'migrated'
    }

    def upsert(product, overwrite: false, migrating: false)
      begin
        migration_status = account.catalogx_migration_status

        if migration_status == MIGRATION_STATE[:default]
          uts_create(product)
        elsif migration_status == MIGRATION_STATE[:migrated]
          handle_request(
            "accounts/#{account.uuid}/products",
            :post,
            query_params: {overwrite: overwrite, migrating: false},
            body: product
          )
        else
          uts_create(product)
        end
      rescue
        catalogx_client_statsd_exception('upsert', migration_status)
        raise
      end
    end

    def batch_upsert(products, overwrite: false, migrating: false)
      migration_status = account.catalogx_migration_status || MIGRATION_STATE[:default]

      begin
        if migration_status == MIGRATION_STATE[:default]
          uts_batch(products, overwrite)
        elsif migration_status == MIGRATION_STATE[:double_write]
          uts_batch(products, overwrite)
        elsif migration_status == MIGRATION_STATE[:migrated]
          handle_request( "accounts/#{account.uuid}/products/batch_upsert",
            :post, query_params: {overwrite: overwrite, migrating: migrating},
            body: {"products" => products})
        else
          uts_batch(products, overwrite)
        end
      rescue
        catalogx_client_statsd_exception('batch', migration_status)
        raise
      end
    end

    def set_out_of_stock(catalog_uuid)
      begin
        migration_status = account.catalogx_migration_status

        if migration_status == MIGRATION_STATE[:default]
          uts_set_stock(catalog_uuid)
        elsif migration_status == MIGRATION_STATE[:double_write]
          uts_set_stock(catalog_uuid)
        elsif migration_status == MIGRATION_STATE[:migrated]
          handle_request(
            "accounts/#{account.uuid}/products/set_out_of_stock",
            :post,
            body: {"catalog_uuid" => catalog_uuid}
          )
        else
          uts_set_stock(catalog_uuid)
        end
      rescue
        catalogx_client_statsd_exception('set_out_of_stock', migration_status)
        raise
      end
    end

    def uts_create(product)
      CatalogServiceClient::Product
        .for_account(account.uuid, "catalog_controller").create(product)
    end

    def uts_batch(products, overwrite)
      if overwrite
        CatalogServiceClient::Product
          .for_account(account.uuid, "catalog_controller")
          .bulk_create(products)
      else
        CatalogServiceClient::Product
          .for_account(account.uuid, "catalog_controller")
          .bulk_update(products)
      end
    end

    def uts_set_stock(catalog_uuid)
        CatalogServiceClient::Product
          .for_account(account.uuid, "catalog_controller")
          .set_out_of_stock(catalog_uuid, account.uuid)
    end

    def catalogx_client_statsd_exception(method, migration_status)
      $statsd.increment(
        "catalogx_client.#{method}.exception",
        tags: [
          "account_uuid:#{account.uuid}",
          "migration_status:#{migration_status}"
        ]
      )
    end
  end
end
