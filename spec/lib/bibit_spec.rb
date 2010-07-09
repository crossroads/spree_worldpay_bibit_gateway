require 'spec/spec_helper.rb'
require File.join(WorldpayBibitGatewayExtension.root,
                  'lib', 'bibit.rb')

include ActiveMerchant::Billing

module BibitGatewaySpecHelper
  def successful_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                "http://dtd.bibit.com/paymentService_v1.dtd">
<paymentService version="1.4" merchantCode="XXXXXXXXXXXXXXX">
  <reply>
    <orderStatus orderCode="R50704213207145707">
      <payment>
        <paymentMethod>VISA-SSL</paymentMethod>
        <amount value="15000" currencyCode="HKD" exponent="2" debitCreditIndicator="credit"/>
        <lastEvent>AUTHORISED</lastEvent>
        <CVCResultCode description="UNKNOWN"/>
        <AVSResultCode description="UNKNOWN"/>
        <balance accountType="IN_PROCESS_AUTHORISED">
          <amount value="15000" currencyCode="HKD" exponent="2" debitCreditIndicator="credit"/>
        </balance>
        <cardNumber>4111********1111</cardNumber>
        <riskScore value="1"/>
      </payment>
    </orderStatus>
  </reply>
</paymentService>

    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                "http://dtd.bibit.com/paymentService_v1.dtd">
<paymentService version="1.4" merchantCode="XXXXXXXXXXXXXXX">
  <reply>
    <orderStatus orderCode="R12538568107150952">
      <error code="7">
        <![CDATA[Invalid payment details : Card number : 4111********1111]]>
      </error>
    </orderStatus>
  </reply>
</paymentService>

    RESPONSE
  end

  def sample_authorization_request
    <<-REQUEST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE paymentService PUBLIC "-//RBS WorldPay//DTD RBS WorldPay PaymentService v1//EN" "http://dtd.wp3.rbsworldpay.com/paymentService_v1.dtd">
<paymentService merchantCode="XXXXXXXXXXXXXXX" version="1.4">
<submit>
  <order installationId="0000000000" orderCode="R85213364408111039">
    <description>Products Products Products</description>
    <amount value="100" exponent="2" currencyCode="HKD"/>
    <orderContent>Products Products Products</orderContent>
    <paymentDetails>
      <VISA-SSL>
        <cardNumber>4242424242424242</cardNumber>
        <expiryDate>
          <date month="09" year="2011"/>
        </expiryDate>
        <cardHolderName>Jim Smith</cardHolderName>
        <cvc>123</cvc>
        <cardAddress>
          <address>
            <firstName>Jim</firstName>
            <lastName>Smith</lastName>
            <street>1234 My Street</street>
            <houseName>Apt 1</houseName>
            <postalCode>K1C2N6</postalCode>
            <city>Ottawa</city>
            <state>ON</state>
            <countryCode>CA</countryCode>
            <telephoneNumber>(555)555-5555</telephoneNumber>
          </address>
        </cardAddress>
      </VISA-SSL>
      <session id="asfasfasfasdgvsdzvxzcvsd" shopperIPAddress="127.0.0.1"/>
    </paymentDetails>
    <shopper>
      <browser>
        <acceptHeader>application/json, text/javascript, */*</acceptHeader>
        <userAgentHeader>Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.19</userAgentHeader>
      </browser>
    </shopper>
  </order>
</submit>
</paymentService>

    REQUEST
  end

  def credit_card(number = '4242424242424242', options = {})
    defaults = {
      :number => number,
      :month => 9,
      :year => Time.now.year + 1,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :verification_value => '123',
      :type => 'visa'
    }.update(options)

    CreditCard.new(defaults)
  end

  def address(options = {})
    {
      :name     => 'Jim Smith',
      :address1 => '1234 My Street',
      :address2 => 'Apt 1',
      :company  => 'Widgets Inc',
      :city     => 'Ottawa',
      :state    => 'ON',
      :zip      => '',
      :country  => 'CA',
      :phone    => '(555)555-5555',
      :fax      => '(555)555-6666'
    }.update(options)
  end

end

describe BibitGateway do

  include BibitGatewaySpecHelper

  before(:all) do
    Base.mode = :test

    # Make methods public for testing
    BibitGateway.send(:public, :build_authorization_request)
    BibitGateway.send(:public, :build_request)

    @gateway = BibitGateway.new(
      :inst_id => '15232442',
      :login => 'testlogin',
      :password => 'testpassword',
      :test => '1'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = {:billing_address => address,
                :email => "test@example.com",
                :customer => "test@example.com",
                :ip => "127.0.0.1",
                :accept_header => "application/json, text/javascript, */*",
                :user_agent_header => "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.19",
                :session_id => "0f2fe9a4790bf7890fb6d03e7ddc0e25",
                :order_id => "R852133644",
                :order_content => "Products Products Products",
                :description => "Products Products Products",
                :shipping => 20,
                :tax => 0,
                :subtotal => 100}
  end

  it "should be able to set postcode to dummy value if not given" do
    auth_request = @gateway.build_authorization_request(@amount, @credit_card, @options.clone)
    final_request = @gateway.build_request(auth_request)
    xml = REXML::Document.new(final_request)
    postcode_path = '/paymentService/submit/order/paymentDetails/VISA-SSL/cardAddress/address/postalCode'
    postcode = REXML::XPath.first(xml, postcode_path).text
    postcode.should == "0000"
  end

  it "should be able to generate a unique order number" do
    auth_request = @gateway.build_authorization_request(@amount, @credit_card, @options.clone)
    final_request = @gateway.build_request(auth_request)
    xml = REXML::Document.new(final_request)
    ordercode_path = '/paymentService/submit/order'
    ordercode = REXML::XPath.first(xml, ordercode_path).attributes["orderCode"]
    # Make sure that the order number has an
    # 8 digit timestamp appended.
    order_regex = Regexp.new("(#{@options[:order_id]})\\d{8}")
    ordercode[order_regex, 1].should_not == nil
  end

  it "should be able to make a successful purchase" do
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    response.success?.should == true
  end

  it "should be able to handle a failed purchase" do
    @gateway.stubs(:ssl_post).returns(failed_purchase_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    response.success?.should == false
  end

  it "should have valid country and card type support" do
    BibitGateway.supported_countries.should == ['HK']
    BibitGateway.supported_cardtypes.should == [:visa,
                                                :master,
                                                :american_express,
                                                :discover]
  end

end

