module Spree
  # Gateway for Adyen Hosted Payment Pages solution
  class Gateway::AdyenHPP < Gateway
    include AdyenCommon

    preference :skin_code, :string
    preference :shared_secret, :string

    def source_required?
      false
    end

    def auto_capture?
      false
    end

    def capture(amount, response_code, gateway_options = {})
      value = { :currency => Config.currency, :value => amount }
      response = provider.capture_payment(response_code, value)

      if response.success?
        response.class.send(:define_method, :authorization, -> { response.psp_reference })
        response.class.send(:define_method, :avs_result, -> { {} })
        response.class.send(:define_method, :cvv_result, -> {})
      else
        # TODO confirm the error response will always have these two methods
        def response.to_s
          "#{result_code} - #{refusal_reason}"
        end
      end

      response
    end

    # According to Spree Processing class API the response object should respond
    # to an authorization method which return value should be assigned to payment
    # response_code
    def void(response_code, gateway_options = {})
      response = provider.cancel_payment(response_code)

      if response.success?
        response.class.send(:define_method, :authorization, -> { response.psp_reference })
      else
        # TODO confirm the error response will always have these two methods
        def response.to_s
          "#{result_code} - #{refusal_reason}"
        end
      end
      response
    end

    # Spree usually grabs these from a Credit Card object but when using
    # Adyen Hosted Payment Pages where we wouldn't keep # the credit card object
    # as that entered outside of the store forms
    def actions
      %w{capture void}
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      !payment.void?
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    def method_type
      "adyen"
    end
  end
end
