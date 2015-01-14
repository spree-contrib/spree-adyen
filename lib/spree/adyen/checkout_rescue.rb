module Spree
  module Adyen
    module CheckoutRescue
      extend ActiveSupport::Concern

      included do
        rescue_from Adyen::Enrolled3DError, :with => :rescue_from_adyen_3d_enrolled

        def rescue_from_adyen_3d_enrolled(exception)
          session[:adyen_gateway_id] = exception.gateway.id
          session[:adyen_gateway_name] = exception.gateway.class.name
          session[:payment_identifier] = exception.gateway_options[:payment_identifier]

          @adyen_3d_response = exception
          render 'spree/checkout/adyen_3d_form'
        end

        rescue_from Adyen::HPPRedirectError, :with => :rescue_from_adyen_hpp_redirect

        def rescue_from_adyen_hpp_redirect(exception)
      
          payment = exception.source.payments.processing.last

          redirect_params = {
            currency_code:      current_order.currency,
            ship_before_date:   Date.tomorrow,
            session_validity:   10.minutes.from_now,
            recurring:          false,
            merchant_reference: "#{payment.order.number}-#{payment.identifier}",
            merchant_account:   exception.source.payment_method.merchant_account,
            skin_code:          exception.source.payment_method.skin_code,
            shared_secret:      exception.source.payment_method.shared_secret,
            payment_amount:     (payment.order.total.to_f * 100).to_int,  
            brandCode:          exception.source.brand_code
          }
          
          redirect_params[:resURL] = adyen_confirmation_url

          # TODO: For completeness offer configuration to render a view that will auto POST this information rather than a GET request
          redirect_to ::Adyen::Form.redirect_url(@redirect_params.merge(redirect_params))
        end

      end
    end
  end
end
