module Spree
  module Adyen
    module CheckoutRescue
      extend ActiveSupport::Concern

      included do
        rescue_from Adyen::Enrolled3DError, :with => :rescue_from_adyen_3d_enrolled

        def rescue_from_adyen_3d_enrolled(exception)
          session[:adyen_gateway_id] = exception.gateway.id
          session[:adyen_gateway_name] = exception.gateway.class.name

          @adyen_3d_response = exception
          render 'spree/checkout/adyen_3d_form'
        end
      end
    end
  end
end
