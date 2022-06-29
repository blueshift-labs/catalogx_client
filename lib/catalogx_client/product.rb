module CatalogXClient
  class Product < BaseClient
    extend ShouldBelongToAccount

    def upsert(product, caller_ctx, overwrite: false, testing: false)
      url_path = "accounts/#{@account_uuid}/products"

      if @migration_status == 'log_responses'
        begin
          params = { overwrite: overwrite, testing: testing }
          resp = handle_request(url_path, :post, query_params: params, body: product)
          api = overwrite ? 'create' : 'update'
          CATALOGX_LOGGER.info("service=catalogx|response=#{resp.to_s}")
        rescue => ex
          CATALOGX_LOGGER.error("#{ex}")
          catalogx_client_statsd_exception('upsert', @migration_status)
        end

        resp = uts_create(product)
        api = overwrite ? 'create' : 'update'
        CATALOGX_LOGGER.info("service=uts|api=#{api}|response=#{resp.to_s}")
        resp
      elsif @migration_status == 'complete'
        params = { overwrite: overwrite }
        resp = handle_request(url_path, :post, query_params: params, body: product)
      else
        uts_create(product)
      end
    end

    def batch_upsert(products, caller_ctx, overwrite: false, testing: false)
      url_path = "accounts/#{@account_uuid}/products/batch_upsert"

      if @migration_status == 'log_responses'
        begin
          params = { overwrite: overwrite, testing: testing }
          resp = handle_request(url_path, :post, query_params: params, body: {products: products})
          api = overwrite ? 'bulk_create' : 'bulk_update'
          CATALOGX_LOGGER.info("service=catalogx|api=#{api}|response=#{resp.to_s}")
        rescue => ex
          CATALOGX_LOGGER.error("#{ex}")
          catalogx_client_statsd_exception('batch_upsert', @migration_status)
        end

        resp = uts_batch(products, overwrite, caller_ctx)
        api = overwrite ? 'bulk_create' : 'bulk_update'
        CATALOGX_LOGGER.info("service=uts|api=#{api}|response=#{resp.to_s}")
        resp
      elsif @migration_status == 'complete'
        params = { overwrite: overwrite }
        resp = handle_request(url_path, :post, query_params: params, body: {products: products})
      else
        uts_batch(products, overwrite, caller_ctx)
      end
    end

    def set_out_of_stock(catalog_uuid, caller_ctx)
      url_path = "accounts/#{@account_uuid}/products/set_out_of_stock"
      if @migration_status == 'log_responses'
        begin
          params = { overwrite: overwrite }
          body =  {"catalog_uuid" => catalog_uuid}
          resp = handle_request(url_path, :post, query_params: params, body: body)
          CATALOGX_LOGGER.info("service=catalogx|api=set_out_of_stock|response=#{resp.to_s}")
        rescue => ex
          CATALOGX_LOGGER.error("#{ex}")
          catalogx_client_statsd_exception('set_out_of_stock', @migration_status)
        end

        resp = uts_set_stock(catalog_uuid)
        CATALOGX_LOGGER.info("service=uts|api=set_out_of_stock|response=#{resp.to_s}")
        resp
      elsif @migration_status == 'complete'
        params = { overwrite: overwrite }
        body = {"catalog_uuid" => catalog_uuid}
        handle_request(url_path, :post, query_params: params, body: body)
      else
        uts_set_stock(catalog_uuid)
      end
    end

    def uts_create(product, caller_ctx)
      CatalogServiceClient::Product
        .for_account(@account_uuid, "catalog_#{caller_ctx}").create(product)
    end

    def uts_batch(products, overwrite, caller_ctx)
      if overwrite
        CatalogServiceClient::Product
          .for_account(@account_uuid, "catalog_#{caller_ctx}")
          .bulk_create(products)
      else
        CatalogServiceClient::Product
          .for_account(@account_uuid, "catalog_#{caller_ctx}")
          .bulk_update(products)
      end
    end

    def uts_set_stock(catalog_uuid, caller_ctx)
        CatalogServiceClient::Product
          .for_account(@account_uuid, "catalog_#{caller_ctx}")
          .set_out_of_stock(catalog_uuid, @account_uuid)
    end

    def catalogx_client_statsd_exception(method, migration_status)
      $statsd.increment(
        "catalogx_client.#{method}.exception",
        tags: [
          "account_uuid:#{@account_uuid}",
          "migration_status:#{migration_status}"
        ]
      )
    end
  end
end
