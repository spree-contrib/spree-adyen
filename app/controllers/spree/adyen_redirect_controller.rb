module Spree
  class AdyenRedirectController < StoreController
    before_filter :check_signature, :only => :confirm

    def confirm
      order = current_order

      unless authorized?
        flash.notice = Spree.t(:payment_processing_failed)
        redirect_to checkout_state_path(order.state) and return
      end

      # cant set payment to complete here due to a validation
      # in order transition from payment to complete (it requires at
      # least one pending payment)
      payment = order.payments.create!(
        :amount => order.total,
        :payment_method => payment_method,
        :response_code => params[:pspReference]
      )

      order.next

      if order.complete?
        # otherwise payment would remain in checkout state
        payment.pend!

        flash.notice = Spree.t(:order_processed_successfully)
        redirect_to order_path(order, :token => order.token)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    private
      def check_signature
        unless ::Adyen::Form.redirect_signature_check(params, payment_method.preferred_shared_secret)
          raise "Payment Method not found."
        end
      end

      # TODO find a way to send the payment method id to Adyen servers and get
      # it back here to make sure we find the right payment method
      def payment_method
        @payment_method ||= Gateway::AdyenPayment.last # find(params[:merchantReturnData])
      end

      def authorized?
        params[:authResult] == "AUTHORISED"
      end
  end
end
