class CreateWorldpayGateway < ActiveRecord::Migration

  def self.up

    login     = GatewayOption.create(:name => "login",
                                     :description => "Username (Account Number)")
    instID  = GatewayOption.create(:name => "inst_id",
                                     :description => "Installation ID")
    password  = GatewayOption.create(:name => "password",
                                     :description => "Password for Installation")
    test      = GatewayOption.create(:name => "test",
                                     :description => "Process payments in test-mode? (0=false,1=true)")

    worldpay = Gateway.create(:clazz => 'ActiveMerchant::Billing::BibitGateway',
      :name => 'RBS WorldPay (Bibit)',
      :description => "Active Merchant's RBS WorldPay (Bibit) Gateway",
      :gateway_options => [login, password, test, instID])

    # Set worldpay as default gateway.
    gateway_conf = GatewayConfiguration.first
    gateway_conf.gateway_id = worldpay.id
    gateway_conf.save!

  end

  def self.down
    worldpay = Gateway.find_by_name('RBS WorldPay (Bibit)')
    worldpay.destroy
  end

end

