module CatalogXClient
  class Product < BaseClient
    extend ShouldBelongToAccount

    # def find(search_params={})
    #   handle_request("accounts/#{account_uuid}/products", :get, params: search_params)
    # end
    #
    # def get(product_uuid)
    #   handle_request("accounts/#{account_uuid}/products/#{product_uuid}", :get)
    # end

    def create(product_params)
      data = {"product" => product_params}
      handle_request("accounts/#{account_uuid}/products", :post, body: data)
    end

   def bulk_create(product_params)
     data = {"products" => product_params}
     handle_request("accounts/#{account_uuid}/products/bulk_create", :post, body: data)
   end

    def update(product_uuid, product_params)
      data = {"product" => product_params}
      handle_request("accounts/#{account_uuid}/products/#{product_uuid}", :put, body: data)
    end

    def bulk_update(product_params)
      data = {"products" => product_params}
      handle_request("accounts/#{account_uuid}/products/bulk_update", :put, body: data)
    end

    def destroy(product_uuid)
      handle_request("accounts/#{account_uuid}/products/#{product_uuid}", :delete)
    end

    # def track_statistics(product_stats_arr)
    #   data = {"products" => product_stats_arr}
    #   handle_request("accounts/#{account_uuid}/products/track_statistics", :post, body: data)
    # end
    #
    # def statistics(catalog_uuids=nil)
    #   params = nil
    #   params = {catalog_uuid: catalog_uuids} if catalog_uuids.present?
    #   handle_request("accounts/#{account_uuid}/products/statistics", :get, params: params)
    # end

    def set_out_of_stock(catalog_uuid, account_uuid)
      data = {"catalog_uuid" => catalog_uuid, "account_uuid" => account_uuid}
      handle_request("accounts/#{account_uuid}/products/set_out_of_stock", :put, body: data)
    end
  end
end
