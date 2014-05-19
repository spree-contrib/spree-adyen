module Spree
  class Gateway::AdyenPaymentEncrypted < Gateway
    include AdyenCommon

    preference :public_key, :string

    def auto_capture?
      false
    end

    def method_type
      'adyen_encrypted'
    end

    def payment_profiles_supported?
      true
    end

    def authorize(amount, source, gateway_options = {})
      card = { encrypted: { json: source.encrypted_data } }
      authorize_on_card amount, source, gateway_options, card
    end

    # Do a symbolic authorization, e.g. 1 dollar, so that we can grab a recurring token
    #
    # NOTE Ensure that your Adyen account Capture Delay is set to *manual* otherwise
    # this amount might be captured from customers card. See Settings > Merchant Settings
    # in Adyen dashboard
    def create_profile(payment)
      card = { encrypted: { json: payment.source.encrypted_data } }
      create_profile_on_card payment, card
    end

    def add_contract(source, user, shopper_ip)
      card = { encrypted: { json: source.encrypted_data } }
      set_up_contract source, card, user, shopper_ip
    end
  end
end
