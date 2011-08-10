module Spree
  module PaymentGatewayBibit
    # Adds session_id to minimal gateway options, for Bibit Gateway.
    def minimal_gateway_options
      # Custom code to retrieve list of products from order.
      product_list = ""
      checkout.order.line_items.each do |line_item|
        product_list << "product: #{line_item.variant.name}\n"
        product_list << "  barcode: #{line_item.variant.sku}\n"
      end
      default_description = "Purchase on #{Time.now}"
      {:email => checkout.email,
       :customer => checkout.email,
       :ip => checkout.ip_address,
       :accept_header => checkout.accept_header,
       :user_agent_header => checkout.user_agent_header,
       :session_id => checkout.session_id,
       :order_id => checkout.order.number,
       :order_content => product_list,
       :description => default_description,
       :shipping => checkout.order.ship_total * 100,
       :tax => checkout.order.tax_total * 100,
       :subtotal => checkout.order.item_total * 100}
    end
  end
end

