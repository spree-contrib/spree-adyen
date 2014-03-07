module Spree
  class Gateway::AdyenPayment < Gateway
    include AdyenCommon

    def auto_capture?
      false
    end

    def payment_profiles_supported?
      true
    end

    def authorize(amount, source, gateway_options = {})
      reference = gateway_options[:order_id]
      amount = { :currency => Config.currency, :value => amount }
      shopper = { :reference => gateway_options[:customer_id],
                  :email => gateway_options[:email],
                  :ip => gateway_options[:ip],
                  :statement => "Order # #{gateway_options[:order_id]}" }

      card = { :holder_name => source.name,
               :number => source.number,
               :cvc => source.verification_value,
               :expiry_month => source.month,
               :expiry_year => source.year }

      if source.gateway_customer_profile_id.present?
        # NOTE uses the lastest customer credit card stored, the profile_id here
        # is not actually the recurring_detail_reference
        response = provider.authorise_recurring_payment reference, amount, shopper
      else
        response = provider.authorise_payment reference, amount, shopper, card
      end

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

    # Do a symbolic authorization, e.g. 1 dollar, so that we can grab a recurring token
    #
    # NOTE Ensure that your Adyen account Capture Delay is set to *manual* otherwise
    # this amount might be captured from customers card. See Settings > Merchant Settings
    # in Adyen dashboard
    def create_profile(payment)
      unless payment.source.gateway_customer_profile_id.present?

        shopper = { :reference => payment.order.user.id,
                    :email => payment.order.user.email,
                    :ip => payment.order.last_ip_address,
                    :statement => "Order # #{payment.order.number}" }

        card = { :holder_name => payment.source.name,
                 :number => payment.source.number,
                 :cvc => payment.source.verification_value,
                 :expiry_month => payment.source.month,
                 :expiry_year => payment.source.year }

        amount = { :currency => Config.currency, :value => 100 }

        response = provider.authorise_payment payment.order.number, amount, shopper, card, true

        if response.success?
          # NOTE Just to tell that this source have been set to use recurring payments
          # It doesn't actually save the recurring_detail_reference (adyen api
          # doesn't give it back on the authorization response). One possible way
          # to do it here would be to get a list of recurring payments details via
          # another api call and grab the reference matching the current payment here
          payment.source.update_column(:gateway_customer_profile_id, response.psp_reference)
        else
          logger.error(Spree.t(:gateway_error))
          logger.error("  #{response.to_yaml}")
          raise Core::GatewayError.new(response.fault_message)
        end

        response
      end
    end
  end
end
