module Spree
  class Gateway::AdyenPayment < Gateway
    preference :api_username, :string
    preference :api_password, :string
    preference :merchant_account, :string

    preference :adyen_hpps, :boolean, default: false
    preference :skin_code, :string
    preference :shared_secret, :string

    def provider_class
      ::Adyen::API
    end

    def source_required?
      !preferred_adyen_hpps.present?
    end

    def provider
      ::Adyen.configuration.api_username = preferred_api_username
      ::Adyen.configuration.api_password = preferred_api_password
      ::Adyen.configuration.default_api_params[:merchant_account] = preferred_merchant_account

      provider_class
    end

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

    def method_type
      preferred_adyen_hpps ? "adyen" : super
    end

    # Spree usually grabs these from a Credit Card object but some users
    # may use Adyen Hosted Payment Pages instead where we wouldn't keep
    # the credit card object for the payment
    def actions
      %w{capture}
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end
  end
end
