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
          def response.authorization; psp_reference; end
          def response.avs_result; {}; end
          def response.cvv_result; {}; end
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
          def response.authorization; psp_reference; end
        else
          # TODO confirm the error response will always have these two methods
          def response.to_s
            "#{result_code} - #{refusal_reason}"
          end
        end
        response
      end

      private
        def authorize_on_card(amount, source, gateway_options, card)
          reference = gateway_options[:order_id]

          amount = { :currency => Config.currency, :value => amount }
          shopper = { :reference => gateway_options[:customer_id],
                      :email => gateway_options[:email],
                      :ip => gateway_options[:ip],
                      :statement => "Order # #{gateway_options[:order_id]}" }

          if source.gateway_customer_profile_id.present?
            # NOTE uses the LATEST customer credit card stored, the profile_id here
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

        def create_profile_on_card(payment, card)
          unless payment.source.gateway_customer_profile_id.present?

            shopper = { :reference => payment.order.user.id,
                        :email => payment.order.user.email,
                        :ip => payment.order.last_ip_address,
                        :statement => "Order # #{payment.order.number}" }


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

    module ClassMethods
    end
  end
end
