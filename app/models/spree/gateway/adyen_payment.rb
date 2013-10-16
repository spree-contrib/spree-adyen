module Spree
  class Gateway::AdyenPayment < Gateway
    include AdyenCommon

    def auto_capture?
      false
    end

    def authorize(amount, source, gateway_options = {})
      provider.authorise_payment(
        gateway_options[:order_id],

        { :currency => Config.currency, :value => amount },

        { :reference => gateway_options[:email],
          :email => gateway_options[:email],
          :ip => gateway_options[:ip],
          :statement => 'invoice number 123456' },

        { :holder_name => "#{source.first_name} #{source.last_name}",
          :number => '4111111111111111',
          :cvc => '737',
          :expiry_month => "06",
          :expiry_year => "2016" }
      )
    end

    def capture(amount, response_code, gateway_options = {})
      value = { :currency => Config.currency, :value => amount }
      response = provider.capture_payment(response_code, value)

      # spree/payment/processing calls this method
      def response.authorization; end

      response
    end
  end
end
