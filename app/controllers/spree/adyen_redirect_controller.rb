module Spree
  class AdyenRedirectController < StoreController
    before_filter :check_signature, :only => :confirm

    skip_before_filter :verify_authenticity_token

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
        flash.notice = Spree.t(:order_processed_successfully)
        redirect_to order_path(order, :token => order.guest_token)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    def authorise3d
      order = current_order

      if params[:MD].present? && params[:PaRes].present?
        md = params[:MD]
        pa_response = params[:PaRes]

        gateway_class = session[:adyen_gateway_name].constantize
        gateway = gateway_class.find(session[:adyen_gateway_id])

        response3d = gateway.authorise3d(md, pa_response, request.ip, request.headers.env)

        if response3d.success?
          payment = order.payments.create!(
            :amount => order.total,
            :payment_method => gateway,
            :response_code => response3d.psp_reference
          )

          list = gateway.provider.list_recurring_details(order.user_id.present? ? order.user_id : order.email)

          if list.details && list.details.empty?
            flash.notice = "Could not find any recurring details"
            redirect_to checkout_state_path(order.state) and return
          else
            credit_card = Spree::CreditCard.create! do |cc|
              cc.month = list.details.last[:card][:expiry_date].month
              cc.year = list.details.last[:card][:expiry_date].year
              cc.name = list.details.last[:card][:holder_name]
              cc.cc_type = list.details.last[:variant]
              cc.last_digits = list.details.last[:card][:number]
              cc.gateway_customer_profile_id = list.details.last[:recurring_detail_reference]
            end
          end

          # Avoid this payment from being processed and so authorised again
          # once the order transitions to complete state.
          # See Spree::Order::Checkout for transition events
          payment.started_processing!

          # We want to avoid callbacks such as Payment#create_payment_profile on after_save
          payment.update_columns source_id: credit_card.id, source_type: credit_card.class.name

          order.next

          if order.complete?
            flash.notice = Spree.t(:order_processed_successfully)
            redirect_to order_path(order, :token => order.guest_token)
          else
            if order.errors.any?
              flash.notice = order.errors.full_messages.inspect
            end

            redirect_to checkout_state_path(order.state)
          end
        else
          flash.notice = response3d.error.inspect
          redirect_to checkout_state_path(order.state)
        end
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    private

      def authorized?
        params[:authResult] == "AUTHORISED"
      end

      def check_signature
        unless ::Adyen::Form.redirect_signature_check(params, payment_method.shared_secret)
          raise "Payment Method not found."
        end
      end

      # TODO find a way to send the payment method id to Adyen servers and get
      # it back here to make sure we find the right payment method
      def payment_method
        @payment_method ||= Gateway::AdyenHPP.last # find(params[:merchantReturnData])
      end

  end
end
