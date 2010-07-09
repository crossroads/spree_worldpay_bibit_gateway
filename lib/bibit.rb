# Created by Amit kumar
# email: ask4amit@gmail.com
# 15th Aug, 2009

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BibitGateway < Gateway

      #Access URLS
      TEST_URL_DOMAIN = 'https://secure-test.wp3.rbsworldpay.com/jsp/merchant/xml/paymentService.jsp'
      LIVE_URL_DOMAIN = 'https://secure.wp3.rbsworldpay.com/jsp/merchant/xml/paymentService.jsp'

      # Setting Default Currency = HKD
      self.default_currency = 'HKD'
      self.money_format = :cents

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['HK']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.rbsworldpay.com/'

      # The name of the gateway
      self.display_name = 'RBS Global Gateway'

      def initialize(options = {})
        requires!(options, :login, :password, :test)
        @options = options
        super
      end

      def test?
        @options[:test] || Base.gateway_mode == :test
      end

      def authorize(money, credit_card, options = {})
        requires!(options, :ip,:session_id)
        commit 'authorize', build_authorization_request(money, credit_card, options)
      end

      def authorize_recurring(money, reference_id, options = {})
        requires!(options, :ip,:reference_amount)
        requires!(@options, :reference_login)
        commit 'reference transaction', build_authorization_recurring_request(money, reference_id, options)
      end

      def capture(money, authorization, options = {})
        commit 'capture', build_order_modify_request(authorization,build_capture_request(money, options))
      end

      #TODO for our code
      def void(authorization, options = {})
        commit 'cancel', build_order_modify_request(authorization,build_void_request)
      end

      def credit(money, authorization, options = {})
        commit 'refund', build_order_modify_request(authorization,build_credit_request(money, options))
      end

      def purchase(money, creditcard, options = {})
        #TODO
      end

      def status(authorization)
        commit 'order inquiry', build_order_inquiry_request(authorization)
      end

      private

      def build_request(body)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        xml.declare! :DOCTYPE, :paymentService, :PUBLIC, "-//RBS WorldPay//DTD RBS WorldPay PaymentService v1//EN", "http://dtd.wp3.rbsworldpay.com/paymentService_v1.dtd"
        xml.tag! 'paymentService', 'version'=>"1.4", 'merchantCode' => @options[:login] do
          xml << body
        end
        xml.target!
      end

      def build_authorization_recurring_request(money, reference_id, options)
        billing_address = options[:billing_address] || options[:address]
        currency_code = options[:currency] || currency(money)

        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'submit' do
          xml.tag! 'order', 'orderCode' => options[:order_id] do
            xml.description options[:description]
            #TODO money amount()
            xml.tag! 'amount', :value => amount(money), 'currencyCode' => currency_code, 'exponent' => 2
            xml.tag! 'orderContent',   options[:order_content]
            xml.tag! 'payAsOrder', :orderCode=>reference_id, :merchantCode => @options[:reference_login] do
              xml.tag! 'amount', :value => amount(options[:reference_amount]), 'currencyCode' => currency_code, 'exponent' => 2
            end
          end
        end
        xml.target!
      end

      def build_authorization_request(money, credit_card, options)

        billing_address = options[:billing_address] || options[:address]

        # Puts in a default zip code of 0000 if
        # there is no postal code submitted. Postal codes are not
        # always required in Hong Kong.
        billing_address[:zip] = "0000" if billing_address[:zip].blank?

        # Fix for duplicate orders error:
        # Each order ID is now submitted with a unique timestamp suffix
        options[:order_id] += Time.now.strftime "%d%H%M%S"

        currency_code = options[:currency] || currency(money)

        name_arr = billing_address[:name].split(" ")
        billing_address[:first_name] = name_arr.shift
        billing_address[:last_name] = name_arr.join(" ")

        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'submit' do
          xml.tag! 'order', 'orderCode' => options[:order_id], 'installationId' => @options[:inst_id] do
            xml.description options[:description]
            #TODO money amount()
            xml.tag! 'amount', :value=>amount(money), 'currencyCode' => currency_code, 'exponent' => 2
            xml.tag! 'orderContent', options[:order_content]
            add_credit_card(xml, credit_card, billing_address, options)

            # Add shopper/browser tags for new DTD
            xml.tag! 'shopper' do
              xml.tag! 'browser' do
                xml.tag! 'acceptHeader', options[:accept_header]
                xml.tag! 'userAgentHeader',
                         options[:user_agent_header]
              end
            end
          end
        end
        xml.target!
      end

      def add_credit_card(xml, credit_card, address, options)
        xml.tag! 'paymentDetails' do
          xml.tag! credit_card_type(card_brand(credit_card)) do
            xml.tag! 'cardNumber', credit_card.number
            xml.tag! 'expiryDate' do
              xml.tag! 'date', 'month'=>format(credit_card.month, :two_digits), 'year'=>format(credit_card.year, :four_digits)
            end

            # Hack to pull cardHolderName from billing address.
            xml.tag! 'cardHolderName', address[:name]
            xml.tag! 'cvc', credit_card.verification_value

            #TODO need more details here
            if [ 'switch', 'solo' ].include?(card_brand(credit_card).to_s)
              unless credit_card.start_month.blank? || credit_card.start_year.blank?
                xml.tag! 'startDate' do
                  xml.tag! 'date' ,'month'=>format(credit_card.start_month, :two_digits), 'year'=>format(credit_card.start_year, :four_digits)
                end
              end
              xml.tag! 'issueNumber', format(credit_card.issue_number, :two_digits) unless credit_card.issue_number.blank?
            end
            if address
              xml.tag! 'cardAddress' do
                add_address(xml, 'address', address)
              end
            end
          end
          xml.tag! 'session', 'shopperIPAddress'=> options[:ip], 'id'=>options[:session_id]
        end
      end

      def build_order_modify_request(order_code,body)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'modify' do
          xml.tag! 'orderModification', 'orderCode' => order_code do
            xml << body
          end
        end
        xml.target!

      end

      def build_capture_request(money, options)
        currency_code = options[:currency] || currency(money)
        t=Time.now
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'capture' do
          xml.tag! 'date', 'dayOfMonth'=>t.day, 'month'=>t.month, 'year'=>t.year
          xml.tag! 'amount', :value=>amount(money), 'currencyCode' => currency_code, 'exponent' => 2
        end
        xml.target!
      end

      def build_void_request
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'cancel'
        xml.target!
      end

      def build_credit_request(money, options)
        currency_code = options[:currency] || currency(money)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'refund' do
          xml.tag! 'amount', :value=>amount(money), 'currencyCode' => currency_code, 'exponent' => 2
        end
        xml.target!
      end

      def build_order_inquiry_request(order_code)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'inquiry' do
          xml.tag! 'orderInquiry', 'orderCode' => order_code
        end
        xml.target!

      end

      def add_address(xml, element, address)
        return if address.nil?
        xml.tag! element do
          xml.tag! 'firstName', address[:first_name]
          xml.tag! 'lastName', address[:last_name]
          xml.tag! 'street', address[:address1]
          xml.tag! 'houseName', address[:address2]
          xml.tag! 'postalCode', address[:zip]
          xml.tag! 'city', address[:city]
          xml.tag! 'state', address[:state].blank? ? 'N/A' : address[:state]
          xml.tag! 'countryCode', address[:country]
          xml.tag! 'telephoneNumber', address[:phone]
        end
      end


      # Read the XML message from the gateway and check if it was successful,
			# and also extract required return values from the response.
      def parse(action,xml)
        basepath = '/paymentService/reply/orderStatus'
        response = {}
        response[:message] = ""
        xml = REXML::Document.new(xml)
        # error returned from Bibit
        if (root = REXML::XPath.first(xml, "#{basepath}/error"))
          parse_error(response, root)
        elsif (root = REXML::XPath.first(xml, basepath))
          # Seems response looks ok
          parse_element(response, root)
          response[:action] = action
          check_success(response,action)
        else
          response[:message] = "No valid XML response message received. \
                                Probably wrong credentials supplied with HTTP header."
        end
        # calculate bibit commission if present
        calculate_commission(xml,response)
        append_error_messages(response)
        response
      end

      # Parse the <ProcessingStatus> Element which contains all important information
      def parse_element(response, node)
        if node.has_elements?
          response[:ok] = true if node.name == "ok"
          node.elements.each{|e| parse_element(response, e) }
          node.attributes.each do |k, v|
            #TODO could be potentially heavy
            # create a list of interesting attributes
            response["#{node.name.underscore}_#{k.underscore}".to_sym] = v #if k == 'currencyID'
          end
        else
          response[node.name.underscore.to_sym] = node.text
          node.attributes.each do |k, v|
            #TODO could be potentially heavy
            # create a list of interesting attributes
            response["#{node.name.underscore}_#{k.underscore}".to_sym] = v #if k == 'currencyID'
          end
        end
      end

      # Parse a generic error response from the gateway
      def parse_error(response,root)
        response[:error_code] = root.attributes["code"]
        response[:message] = root.text
      end

      def calculate_commission(xml,response)
        if (root = REXML::XPath.first(xml,'//balance[@accountType="SETTLED_BIBIT_COMMISSION"]/amount'))
          #commission will be in cents
          response[:bibit_commission] = root.attributes["value"]
        end
      end

      def append_error_messages(response)
        # append iso error messages in the message
        response[:message] += " " + response[:iso8583_return_code_code] if response[:iso8583_return_code_code]
        response[:message] += " " + response[:iso8583_return_code_description] if response[:iso8583_return_code_description]
      end
      def check_success(response,action)
        response[:ok] = true if (action == "authorize" || action == "reference transaction")  && (response[:last_event] == "AUTHORISED")
        response[:ok] = true if (action == "order inquiry") && (response[:last_event])
      end
      #-------------------------------------

      def endpoint_url
        test? ? TEST_URL_DOMAIN  : LIVE_URL_DOMAIN
      end

      def commit(action, request)
        headers = { 'Content-Type' => 'text/xml',
          'Authorization' => encoded_credentials }

        #TODO take out puts comments
        xml_request = build_request(request)

        xmr = ssl_post(endpoint_url, xml_request, headers)

        # Clean up invalid html from RBS site.. (for errors)
        xmr.gsub!("<P>","") if xmr.include?("HTML PUBLIC")

        response = parse(action,xmr)

        build_response(successful?(response), response[:message], response,
          :test => test?
        )

      end

      def credit_card_type(type)
        case type
          when 'visa'             then 'VISA-SSL'
          when 'master'           then 'ECMC-SSL'
          when 'discover'         then 'DISCOVER-SSL'
          when 'american_express' then 'AMEX-SSL'
        end
      end

      def build_response(success, message, response, options = {})
        Response.new(success, message, response, options)
      end

      #      def message_from(response)
      #        response[:message]
      #      end

      # Encode login and password in Base64 to supply as HTTP header
      # (for http basic authentication)
      def encoded_credentials
        credentials = [@options[:login], @options[:password]].join(':')
        "Basic " << Base64.encode64(credentials).strip
      end

      # to check if a request was successful or not
      def successful?(response)
        response[:ok] == true
      end
    end

  end
end

