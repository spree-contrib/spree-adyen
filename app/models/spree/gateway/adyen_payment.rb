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
      card = { :holder_name => source.name,
               :number => source.number,
               :cvc => source.verification_value,
               :expiry_month => source.month,
               :expiry_year => source.year }

      authorize_on_card amount, source, gateway_options, card
    end

    # Do a symbolic authorization, e.g. 1 dollar, so that we can grab a recurring token
    #
    # NOTE Ensure that your Adyen account Capture Delay is set to *manual* otherwise
    # this amount might be captured from customers card. See Settings > Merchant Settings
    # in Adyen dashboard
    def create_profile(payment)
      card = { :holder_name => payment.source.name,
               :number => payment.source.number,
               :cvc => payment.source.verification_value,
               :expiry_month => payment.source.month,
               :expiry_year => payment.source.year }

      create_profile_on_card payment, card
    end

    def add_contract(source, user, shopper_ip)
      card = { :holder_name => source.name,
               :number => source.number,
               :cvc => source.verification_value,
               :expiry_month => source.month,
               :expiry_year => source.year }

      set_up_contract source, card, user, shopper_ip
    end
  end
end
