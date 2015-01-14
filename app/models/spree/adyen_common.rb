module Spree
  module AdyenCommon
    extend ActiveSupport::Concern

    class RecurringDetailsNotFoundError < StandardError; end
    class MissingCardSummaryError < StandardError; end
    class MissingAliasError < StandardError; end

    included do
      preference :api_username, :string
      preference :api_password, :string
      preference :merchant_account, :string

      def merchant_account
        ENV['ADYEN_MERCHANT_ACCOUNT'] || preferred_merchant_account
      end

      def provider_class
        ::Adyen::API
      end

      def provider
        ::Adyen.configuration.api_username = (ENV['ADYEN_API_USERNAME'] || preferred_api_username)
        ::Adyen.configuration.api_password = (ENV['ADYEN_API_PASSWORD'] || preferred_api_password)
        ::Adyen.configuration.default_api_params[:merchant_account] = merchant_account

        provider_class
      end

      # NOTE Override this with your custom logic for scenarios where you don't
      # want to redirect customer to 3D Secure auth
      def require_3d_secure?(amount, source, gateway_options)
        true
      end

      # Receives a source object (e.g. CreditCard) and a shopper hash
      def require_one_click_payment?(source, shopper)
        false
      end

      def capture(amount, response_code, gateway_options = {})
        value = { currency: gateway_options[:currency], value: amount }
        response = provider.capture_payment(response_code, value)

        if response.success?
          def response.authorization; nil; end
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
          def response.authorization; nil; end
        else
          # TODO confirm the error response will always have these two methods
          def response.to_s
            "#{result_code} - #{refusal_reason}"
          end
        end
        response
      end

      def credit(credit_cents, source, response_code, gateway_options)
        amount = { currency: gateway_options[:currency], value: credit_cents }
        response = provider.refund_payment response_code, amount

        if response.success?
          def response.authorization; nil; end
        else
          def response.to_s
            refusal_reason
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

      def authorise3d(md, pa_response, ip, env)
        browser_info = {
          browser_info: {
            accept_header: env['HTTP_ACCEPT'],
            user_agent: env['HTTP_USER_AGENT']
          }
        }

        provider.authorise3d_payment(md, pa_response, ip, browser_info)
      end

      def build_authorise_options(amount, source, gateway_options)
        if gateway_options[:request_env].is_a?(Hash) && require_3d_secure?(amount, source, gateway_options)
          {
            browser_info: {
              accept_header: gateway_options[:request_env]['HTTP_ACCEPT'],
              user_agent: gateway_options[:request_env]['HTTP_USER_AGENT']
            },
            recurring: true
          }
        else
          { recurring: true }
        end
      end

      def build_amount_on_profile_creation(payment)
        { currency: payment.currency, value: payment.money.money.cents }
      end

      private

        def set_up_contract(source, card, user, shopper_ip)
          options = {
            order_id: "User-#{user.id}",
            customer_id: user.id,
            email: user.email,
            ip: shopper_ip,
          }

          response = authorize_on_card 0, source, options, card, { recurring: true }

          if response.success?
            last_digits = response.additional_data["cardSummary"]
            if last_digits.blank? && payment_profiles_supported?
              note = "Payment was authorized but could not fetch last digits.
                      Please request last digits to be sent back to support payment profiles"
              raise Adyen::MissingCardSummaryError, note
            end

            source.last_digits = last_digits
            fetch_and_update_contract source, options[:customer_id]
          else
            response.error
          end
        end

        def authorize_on_card(amount, source, gateway_options, card, options = { recurring: false })
          reference = gateway_options[:order_id]

          options = build_authorise_options(amount, source, gateway_options)

          amount = { currency: gateway_options[:currency], value: amount }

          shopper_reference = if gateway_options[:customer_id].present?
                                gateway_options[:customer_id]
                              else
                                gateway_options[:email]
                              end

          shopper = { :reference => shopper_reference,
                      :email => gateway_options[:email],
                      :ip => gateway_options[:ip],
                      :statement => "Order # #{gateway_options[:order_id]}" }

          response = decide_and_authorise reference, amount, shopper, source, card, options

          raise Adyen::Enrolled3DError.new(response, self, gateway_options) if response.respond_to?(:enrolled_3d?) && response.enrolled_3d?

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

        def decide_and_authorise(reference, amount, shopper, source, card, options)
          recurring_detail_reference = source.gateway_customer_profile_id
          card_cvc = source.verification_value

          if card_cvc.blank? && require_one_click_payment?(source, shopper)
            raise Core::GatewayError.new("You need to enter the card verificationv value")
          end

          if require_one_click_payment?(source, shopper) && recurring_detail_reference.present?
            provider.authorise_one_click_payment reference, amount, shopper, card_cvc, recurring_detail_reference
          elsif recurring_detail_reference.present?
            provider.authorise_recurring_payment reference, amount, shopper, recurring_detail_reference
          else
            provider.authorise_payment reference, amount, shopper, card, options
          end
        end

        def create_profile_on_card(payment, card)
          unless payment.source.gateway_customer_profile_id.present?

            shopper = { :reference => (payment.order.user_id.present? ? payment.order.user_id : payment.order.email),
                        :email => payment.order.email,
                        :ip => payment.order.last_ip_address,
                        :statement => "Order # #{payment.order.number}" }

            # Auth for 0. Adyen will automatically update this to 1 if 0 not supported by Issuer
            amount = 0

            # Still build options as payment may requre 3D Secure
            options = build_authorise_details payment.gateway_options

            response = provider.authorise_payment payment.gateway_options[:order_id], amount, shopper, card, options

            if response.success?

              store_profile_from_alias(payment, response)

              if payment.source.last_digits.blank?
                last_digits = response.additional_data["cardSummary"]
                if last_digits.blank? && payment_profiles_supported?
                  note = "Payment was authorized but could not fetch last digits.
                          Please request last digits to be sent back to support payment profiles"
                  raise Adyen::MissingCardSummaryError, note
                end
                payment.source.last_digits = last_digits
              end

            elsif response.respond_to?(:enrolled_3d?) && response.enrolled_3d?
              raise Adyen::Enrolled3DError.new(response, payment.payment_method)
            else
              logger.error(Spree.t(:gateway_error))
              logger.error("  #{response.to_yaml}")
              raise Core::GatewayError.new(response.fault_message || response.refusal_reason)
            end

            response
          end
        end

        def store_profile_from_alias(payment, response)
          customer_profile_id = response.additional_data["alias"]
          if customer_profile_id.blank? && payment_profiles_supported?
            note = "Payment was authorized but could not fetch alias (customer_profile_id).
                    Please request alias to be sent back to support payment profiles"
            raise Adyen::MissingAliasError, note
          end
          payment.source.update_attribute :gateway_customer_profile_id, response.additional_data["alias"]
        end

        def fetch_and_update_contract(source, shopper_reference)
          list = provider.list_recurring_details(shopper_reference)

          raise RecurringDetailsNotFoundError unless list.details.present?
          card = list.details.find { |c| c[:card][:number] == source.last_digits }
          raise RecurringDetailsNotFoundError unless card.present?

          source.update_columns(
            month: card[:card][:expiry_date].month,
            year: card[:card][:expiry_date].year,
            name: card[:card][:holder_name],
            cc_type: card[:variant],
            last_digits: card[:card][:number],
            gateway_customer_profile_id: card[:recurring_detail_reference]
          )
        end

    end

    module ClassMethods
    end
  end
end
