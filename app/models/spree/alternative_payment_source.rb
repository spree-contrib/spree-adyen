module Spree
  # TODO: Tidy comment!
  # This source is used to store information about redirecting user's to the Adyen HPP source
  # brand_code can obtain the brand of the payment source and if provided and configurtion set with
  # Adyen.configuration. :details
  # then the user will be redirected direct to the payment source (ie paypal) rather than going to the list oif payment options to select from
  # In order fot this record to be created in the Checkout then a brand_code must be provided for Payment.build_source to work
  # brand_code should be set to 'adyen' if you want to use the HPP solution in order for this to work
  class AlternativePaymentSource < Spree::Base

    belongs_to :payment_method
    belongs_to :user, class_name: Spree.user_class, foreign_key: 'user_id'
    has_many :payments, as: :source

    validates :brand_code, presence: true

    def actions
      %w{capture void credit}
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      !payment.void?
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end
  end
end