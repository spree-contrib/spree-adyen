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
      def void(response_code, source, gateway_options = {})
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

      def credit(credit_cents, source, response_code, gateway_options)
        amount = { :currency => Config.currency, :value => credit_cents }
        response = provider.refund_payment response_code, amount

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

      def disable_recurring_contract(source)
        response = provider.disable_recurring_contract source.user_id, source.gateway_customer_profile_id

        if response.success?
          source.update_column :gateway_customer_profile_id, nil
        else
          logger.error(Spree.t(:gateway_error))
          logger.error("  #{response.to_yaml}")
          raise Core::GatewayError.new(response.fault_message || response.refusal_reason)
        end
      end

      private
        def authorize_on_card(amount, source, gateway_options, card)
          reference = gateway_options[:order_id]

          amount = { :currency => Config.currency, :value => amount }

          shopper_reference = if gateway_options[:customer_id].present?
                                gateway_options[:customer_id]
                              else
                                gateway_options[:email]
                              end

          shopper = { :reference => shopper_reference,
                      :email => gateway_options[:email],
                      :ip => gateway_options[:ip],
                      :statement => "Order # #{gateway_options[:order_id]}" }

          if source.gateway_customer_profile_id.present?
            response = provider.authorise_recurring_payment reference, amount, shopper, source.gateway_customer_profile_id
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

            shopper = { :reference => (payment.order.user_id.present? ? payment.order.user_id : payment.order.email),
                        :email => payment.order.email,
                        :ip => payment.order.last_ip_address,
                        :statement => "Order # #{payment.order.number}" }

            amount = { :currency => Config.currency, :value => 100 }

            response = provider.authorise_payment payment.order.number, amount, shopper, card, true

            if response.success?
              # Adyen doesn't give us the recurring reference (token) so we
              # need to reach the api again to grab the token
              list = provider.list_recurring_details(shopper[:reference])
              payment.source.update_columns(
                month: list.details.last[:card][:expiry_date].month,
                year: list.details.last[:card][:expiry_date].year,
                name: list.details.last[:card][:holder_name],
                cc_type: list.details.last[:variant],
                last_digits: list.details.last[:card][:number],
                gateway_customer_profile_id: list.details.last[:recurring_detail_reference]
              )
            else
              logger.error(Spree.t(:gateway_error))
              logger.error("  #{response.to_yaml}")
              raise Core::GatewayError.new(response.fault_message || response.refusal_reason)
            end

            response
          end
        end
    end

    module ClassMethods
    end
  end
end
