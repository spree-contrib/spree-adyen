module Spree
  class Gateway::AdyenPayment < Gateway
    include AdyenCommon

    def auto_capture?
      false
    end

    def authorize(amount, source, gateway_options = {})
      response = provider.authorise_payment(
          gateway_options[:order_id],

          { :currency => Config.currency, :value => amount },

          { :reference => gateway_options[:order_id],
            :email => gateway_options[:email],
            :ip => gateway_options[:ip],
            :statement => "Order # #{gateway_options[:order_id]}" },

          { :holder_name => "#{source.first_name} #{source.last_name}",
            :number => source.number,
            :cvc => source.verification_value,
            :expiry_month => source.month,
            :expiry_year => source.year }
      )

      # Needed to make the response object talk nicely with Spree payment/processing api
      if response.success?
        response.class.send(:define_method, :authorization, -> { response.psp_reference })
        response.class.send(:define_method, :avs_result, -> { {} })
        response.class.send(:define_method, :cvv_result, -> { { 'code' => response.result_code } })
      else
        def response.to_s
          "#{result_code} - #{refusal_reason}"
        end
      end
        
      response
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
