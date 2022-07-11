module CatalogXClient
  class Product < BaseClient

    def self.upsert(product, account_uuid, caller_ctx, overwrite: false)
      account_migration_status = get_migration_status(account_uuid)
      url_path = "accounts/#{account_uuid}/products"

      if account_migration_status == 'log_responses'
        begin
          params = { overwrite: overwrite, testing: true }
          resp = handle_request(url_path, :post, query_params: params, body: product)
          CATALOGX_LOGGER.info("service=catalogx|api=upsert|response=#{resp.to_s}")
        rescue => ex
          CATALOGX_LOGGER.error("#{ex}")
          catalogx_client_statsd_exception('upsert', migration_status, account_uuid)
        end

        resp = uts_create(product, account_uuid)
        CATALOGX_LOGGER.info("service=uts|api=upsert|response=#{resp.to_s}")
        resp
      elsif account_migration_status == 'complete'
        params = { overwrite: overwrite }
        resp = handle_request(url_path, :post, query_params: params, body: product)
      else
        uts_create(product, account_uuid)
      end
    end

    def self.batch_upsert(products, account_uuid, caller_ctx, overwrite: false)
      account_migration_status = get_migration_status(account_uuid)
      url_path = "accounts/#{account_uuid}/products/batch_upsert"

      if account_migration_status == 'log_responses'
        begin
          params = { overwrite: overwrite, testing: true }
          resp = handle_request(url_path, :post, query_params: params, body: {products: products})
          api = overwrite ? 'bulk_create' : 'bulk_update'
          CATALOGX_LOGGER.info("service=catalogx|api=#{api}|response=#{resp.to_s}")
        rescue => ex
          CATALOGX_LOGGER.error("#{ex}")
          catalogx_client_statsd_exception('batch_upsert', account_migration_status, account_uuid)
        end

        resp = uts_batch(products, account_uuid, overwrite, caller_ctx)
        api = overwrite ? 'bulk_create' : 'bulk_update'
        CATALOGX_LOGGER.info("service=uts|api=#{api}|response=#{resp.to_s}")
        resp
      elsif account_migration_status == 'complete'
        params = { overwrite: overwrite }
        resp = handle_request(url_path, :post, query_params: params, body: {products: products})
      else
        uts_batch(products, account_uuid, overwrite, caller_ctx)
      end
    end

    def self.set_out_of_stock(catalog_uuid, account_uuid, caller_ctx)
      account_migration_status = get_migration_status(account_uuid)
      url_path = "accounts/#{account_uuid}/products/set_out_of_stock"

      if account_migration_status == 'log_responses'
        begin
          params = { overwrite: overwrite, testing: true }
          body =  {"catalog_uuid" => catalog_uuid}
          resp = handle_request(url_path, :post, query_params: params, body: body)
          CATALOGX_LOGGER.info("service=catalogx|api=set_out_of_stock|response=#{resp.to_s}")
        rescue => ex
          CATALOGX_LOGGER.error("#{ex}")
          catalogx_client_statsd_exception('set_out_of_stock', account_migration_status, account_uuid)
        end

        resp = uts_set_out_of_stock(catalog_uuid, account_uuid)
        CATALOGX_LOGGER.info("service=uts|api=set_out_of_stock|response=#{resp.to_s}")
        resp
      elsif account_migration_status == 'complete'
        params = { overwrite: overwrite }
        body = {"catalog_uuid" => catalog_uuid}
        handle_request(url_path, :post, query_params: params, body: body)
      else
        uts_set_out_of_stock(catalog_uuid, account_uuid)
      end
    end

    def uts_create(product, account_uuid, caller_ctx)
      CatalogServiceClient::Product
        .for_account(account_uuid, "catalog_#{caller_ctx}").create(product)
    end

    def uts_batch(products, account_uuid, overwrite, caller_ctx)
      if overwrite
        CatalogServiceClient::Product
          .for_account(account_uuid, "catalog_#{caller_ctx}")
          .bulk_create(products)
      else
        CatalogServiceClient::Product
          .for_account(account_uuid, "catalog_#{caller_ctx}")
          .bulk_update(products)
      end
    end

    def uts_set_out_of_stock(catalog_uuid, caller_ctx, account_uuid)
        CatalogServiceClient::Product
          .for_account(account_uuid, "catalog_#{caller_ctx}")
          .set_out_of_stock(catalog_uuid, account_uuid)
    end

    def catalogx_client_statsd_exception(method, migration_status, account_uuid)
      $statsd.increment(
        "catalogx_client.#{method}.exception",
        tags: [
          "account_uuid:#{account_uuid}",
          "migration_status:#{migration_status}"
        ]
      )
    end
  end
end
