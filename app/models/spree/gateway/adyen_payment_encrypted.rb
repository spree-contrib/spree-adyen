module Spree
  class Gateway::AdyenPaymentEncrypted < Gateway
    include AdyenCommon

    preference :public_key, :string

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

          { encrypted: { json: source.verification_value } }
      )

      # Needed to make the response object talk nicely with Spree payment/processing api
      if response.success?
        def response.authorization; psp_reference; end
        def response.avs_result; {}; end
        def response.cvv_result; { 'code' => result_code }; end
      else
        def response.to_s
          "#{result_code} - #{refusal_reason}"
        end
      end
        
      response
    end

    def payment_source_class
        Spree::EncryptedCreditCard
      end

    def method_type
      'adyen_encrypted'
    end
  end
end
