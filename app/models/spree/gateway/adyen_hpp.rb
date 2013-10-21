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
