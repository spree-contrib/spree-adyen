module Spree
  module AdyenCommon
    extend ActiveSupport::Concern

    included do
      preference :api_username, :string
      preference :api_password, :string
      preference :merchant_account, :string

      def provider_class
        ::Adyen::API
      end

      def provider
        ::Adyen.configuration.api_username = preferred_api_username
        ::Adyen.configuration.api_password = preferred_api_password
        ::Adyen.configuration.default_api_params[:merchant_account] = preferred_merchant_account

        provider_class
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
    end

    module ClassMethods
    end
  end
end
