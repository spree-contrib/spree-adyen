module Spree
  PermittedAttributes.source_attributes.push :encrypted_data

  class EncryptedCreditCard < ActiveRecord::Base
    has_many :payments, as: :source

    attr_accessor :encrypted_data, :verification_value

    validates :encrypted_data, presence: true
    validate :expiry_not_in_the_past

    def expiry=(expiry)
      if expiry.present?
        self[:month], self[:year] = expiry.delete(' ').split('/')
        self[:year] = "20" + self[:year] if self[:year].length == 2
      end
    end    

    def verification_value?
      verification_value.present?
    end

    def actions
      %w{capture void credit}
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      !payment.void?
    end

    # Indicates whether its possible to credit the payment.  Note that most gateways require that the
    # payment be settled first which generally happens within 12-24 hours of the transaction.
    def can_credit?(payment)
      return false unless payment.completed?
      return false unless payment.order.payment_state == 'credit_owed'
      payment.credit_allowed > 0
    end

    def has_payment_profile?
      false
    end    

    private

    def expiry_not_in_the_past
      if year.present? && month.present?
        time = "#{year}-#{month}-1".to_time
        if time < Time.zone.now.to_time.beginning_of_month
          errors.add(:base, :card_expired)
        end
      end
    end
  end
end
