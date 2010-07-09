# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class WorldpayBibitGatewayExtension < Spree::Extension
  version "1.0"
  description "Extension for Spree: RBS Worldpay Gateway"
  url "http://yourwebsite.com/rbs_worldpay_bibit_gateway"

  # Please use rbs_worldpay_bibit_gateway/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end

  def activate

    # Add your extension tab to the admin.
    # Requires that you have defined an admin controller:
    # app/controllers/admin/yourextension_controller
    # and that you mapped your admin in config/routes

    Creditcard.class_eval do
      # add gateway methods to the creditcard so we can authorize, capture, etc.
      include Spree::PaymentGatewayBibit
    end

    CheckoutsController.class_eval do

      update.before do
        # update user to current one if user has logged in
        @order.update_attribute(:user, current_user) if current_user

        if (checkout_info = params[:checkout]) and not checkout_info[:coupon_code]
          # overwrite any earlier guest checkout email if user has since logged in,
          checkout_info[:email] = current_user.email if current_user

          # set the ip_address to the most recent one,
          checkout_info[:ip_address] = request.env['REMOTE_ADDR']
          # and set the session id (for Bibit Gateway)
          checkout_info[:session_id] = request.session_options[:id]

          # and also set the request headers to the most recent ones
          # (for RBS worldpay gateway)
          checkout_info[:accept_header] = request.env['HTTP_ACCEPT']
          checkout_info[:user_agent_header] = request.env['HTTP_USER_AGENT']

          # check whether the bill address has changed, and start a fresh record if
          # we were using the address stored in the current user.
          if checkout_info[:bill_address_attributes] and @checkout.bill_address
            # always include the id of the record we must write to - ajax can't refresh the form
            checkout_info[:bill_address_attributes][:id] = @checkout.bill_address.id
            new_address = Address.new checkout_info[:bill_address_attributes]
            if not @checkout.bill_address.same_as?(new_address) and
                 current_user and @checkout.bill_address == current_user.bill_address
              # need to start a new record, so replace the existing one with a blank
              checkout_info[:bill_address_attributes].delete :id
              @checkout.bill_address = Address.new
            end
          end

          # check whether the ship address has changed, and start a fresh record if
          # we were using the address stored in the current user.
          if checkout_info[:shipment_attributes][:address_attributes] and @order.shipment.address
            # always include the id of the record we must write to - ajax can't refresh the form
            checkout_info[:shipment_attributes][:address_attributes][:id] = @order.shipment.address.id
            new_address = Address.new checkout_info[:shipment_attributes][:address_attributes]
            if not @order.shipment.address.same_as?(new_address) and
                 current_user and @order.shipment.address == current_user.ship_address
              # need to start a new record, so replace the existing one with a blank
              checkout_info[:shipment_attributes][:address_attributes].delete :id
              @order.shipment.address = Address.new
            end
          end

        end
      end
    end


  end
end

